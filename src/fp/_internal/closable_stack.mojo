"""A closable lock-free stack: pushes from any thread until one exchange closes it.

A Treiber stack of heap nodes whose head word is the address of the newest
node, zero when empty, or an odd closed marker. Elements leave it only in
whole lists: `close` swaps in the marker and returns every element, and an
exclusive `prune` detaches the list, drops the elements its predicate rejects,
and pushes the survivors back. Nothing pops single nodes, so pushes are free of
ABA: a push links its node to whatever head it read and installs it only if
the head still holds that value, which is then a node in the list (possibly a
reused address, but a live one) or zero.

The closed marker is `1 | tag << 1`; node addresses are even. The tag records
how the stack was closed, so a pruner that finds it closed can treat its
survivors as the closer treated the elements it received.

A close during a prune: the pruner holds the detached survivors while the
closer exchanges the head and receives only what was pushed since the detach.
When the pruner then finds the marker, it does not push its survivors back but
returns them, with the tag, as orphans; the caller hands them to whatever the
closer did with its elements. No survivor is lost or seen twice.

Memory ordering of each atomic operation:

- A push writes its node, then installs it with a compare-exchange that is
  RELEASE on success. Every change of the head is a read-modify-write, so
  the pushes form one release sequence, and the closer's or pruner's ACQUIRE
  read of the head synchronizes with every push before it: each node's value
  and link are visible. Failure is RELAXED: it only reloads the head for the
  next attempt, and a closed marker read that way needs no ordering, since the
  pusher then keeps its value and touches nothing shared.
- `close` and the prune's detach take the list with a compare-exchange that is
  ACQUIRE on success (above) and RELAXED on failure (retry). Neither publishes
  anything: the marker and zero carry no data.
- The prune's splice of survivors is RELEASE on success, as a push, and
  RELAXED on failure.
- The pruning flag is a lock among pruners only: taken with ACQUIRE, released
  with RELEASE. Pushes and closes never wait for it; a pruner that loses skips
  its prune.
- The length hint is updated and read RELAXED. It only decides when to prune.
- `is_closed` loads the head with ACQUIRE, as a reader of the closer's
  decision.

Cost (`probes/race_primitives_cost.mojo`, O3, four cores): uncontended, a
push and its share of a close cost about 58 ns, against 11 ns for a
spin-locked `List`, the price of one allocation per node. With 4, 8 and 16
threads pushing into one stack it took 99-141 ns per push against 209-292 ns
for the lock, since pushers never wait for a preempted holder.

Destroying the stack destroys every element still in it exactly once; it
requires that no other thread uses the stack.
"""
from std.atomic import Atomic, Ordering
from std.memory.alloc import unsafe_alloc

comptime _EMPTY = UInt64(0)


@always_inline
def _closed(head: UInt64) -> Bool:
    return Bool(head & 1)


struct _StackNode[T: Movable & Deinitable](Movable):
    var value: Self.T
    var next: UInt64

    def __init__(out self, var value: Self.T):
        self.value = value^
        self.next = _EMPTY

    def into_value(deinit self) -> Self.T:
        return self.value^


struct _StackShared(Movable):
    """The head word, the pruners' flag and the length hint, on one line of their own."""
    var head: Atomic[UInt64]
    var pruning: Atomic[UInt8]
    var length: Atomic[Int]

    def __init__(out self):
        self.head = Atomic(_EMPTY)
        self.pruning = Atomic(UInt8(0))
        self.length = Atomic(0)


struct _Pruned[T: Movable & Deinitable](Movable):
    """Survivors a prune could not push back because the stack closed, and the close's tag."""
    var orphans: List[Self.T]
    var tag: UInt8

    def __init__(out self):
        self.orphans = List[Self.T]()
        self.tag = 0


struct _ClosableStack[T: Movable & Deinitable](Movable):
    """A lock-free stack of owned elements that closes once; see the module docstring.

    Parameters:
        T: The element type, moved between threads.
    """
    comptime _Node = _StackNode[Self.T]
    var _shared: Pointer[_StackShared, MutUntrackedOrigin]

    def __init__(out self):
        self._shared = unsafe_alloc[_StackShared](1, alignment=64)
        self._shared.unsafe_write(_StackShared())

    def __deinit__(deinit self):
        var head = self._shared[].head.load[ordering=Ordering.RELAXED]()
        if not _closed(head):
            _ = Self._drain(head)
        self._shared.unsafe_deinit_pointee()
        self._shared.unsafe_free()

    @always_inline
    @staticmethod
    def _node(address: UInt64) -> Pointer[_StackNode[Self.T], MutUntrackedOrigin]:
        return Pointer[_StackNode[Self.T], MutUntrackedOrigin](unsafe_from_address=Int(address))

    @staticmethod
    def _drain(var head: UInt64) -> List[Self.T]:
        """Take every element of a detached chain, newest first, freeing its nodes."""
        var values = List[Self.T]()
        while head != _EMPTY:
            var node = Self._node(head)
            head = node[].next
            values.append(node.unsafe_take_pointee().into_value())
            node.unsafe_free()
        return values^

    def push(self, var value: Self.T) -> Optional[Self.T]:
        """Push unless closed; a closed stack returns the value to the caller."""
        var node = unsafe_alloc[_StackNode[Self.T]](1)
        node.unsafe_write(_StackNode[Self.T](value^))
        var head = self._shared[].head.load[ordering=Ordering.RELAXED]()
        while True:
            if _closed(head):
                var refused = node.unsafe_take_pointee().into_value()
                node.unsafe_free()
                return Optional(refused^)
            node[].next = head
            if self._shared[].head.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELEASE](head, UInt64(Int(node))):
                _ = self._shared[].length.fetch_add[ordering=Ordering.RELAXED](1)
                return None

    def close(self, tag: UInt8 = 0) -> List[Self.T]:
        """Close once, returning every element oldest first; empty if already closed.

        Args:
            tag: How the elements are treated, for orphans of a concurrent prune.
        """
        var marker = UInt64(1) | (UInt64(tag) << 1)
        var head = self._shared[].head.load[ordering=Ordering.RELAXED]()
        while True:
            if _closed(head):
                return List[Self.T]()
            if self._shared[].head.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.ACQUIRE](head, marker):
                break
        var values = Self._drain(head)
        values.reverse()
        return values^

    def is_closed(self) -> Bool:
        return _closed(self._shared[].head.load[ordering=Ordering.ACQUIRE]())

    def length(self) -> Int:
        """Elements pushed and not pruned or closed; a hint, possibly stale."""
        return self._shared[].length.load[ordering=Ordering.RELAXED]()

    def prune[keep: def(Self.T) thin -> Bool](self) -> _Pruned[Self.T]:
        """Drop the elements `keep` rejects; one pruner at a time, others skip.

        Survivors return to the stack in their order. If it closed during the
        prune, they are returned as orphans with the close's tag instead.

        Parameters:
            keep: Whether an element stays.
        """
        var pruned = _Pruned[Self.T]()
        var idle = UInt8(0)
        if not self._shared[].pruning.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.ACQUIRE](idle, UInt8(1)):
            return pruned^
        var head = self._shared[].head.load[ordering=Ordering.RELAXED]()
        while True:
            if _closed(head) or head == _EMPTY:
                self._shared[].pruning.store[ordering=Ordering.RELEASE](0)
                return pruned^
            if self._shared[].head.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.ACQUIRE](head, _EMPTY):
                break
        # Survivors, newest first, relinked in their order; rejected nodes freed.
        var first = _EMPTY
        var last = _EMPTY
        var removed = 0
        var cursor = head
        while cursor != _EMPTY:
            var node = Self._node(cursor)
            var following = node[].next
            if keep(node[].value):
                node[].next = _EMPTY
                if last == _EMPTY:
                    first = cursor
                else:
                    Self._node(last)[].next = cursor
                last = cursor
            else:
                removed += 1
                _ = node.unsafe_take_pointee()
                node.unsafe_free()
            cursor = following
        if first != _EMPTY:
            var current = self._shared[].head.load[ordering=Ordering.RELAXED]()
            while True:
                if _closed(current):
                    pruned.orphans = Self._drain(first)
                    pruned.orphans.reverse()
                    pruned.tag = UInt8((current >> 1) & 0x7F)
                    removed += len(pruned.orphans)
                    break
                Self._node(last)[].next = current
                if self._shared[].head.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELEASE](current, first):
                    break
        _ = self._shared[].length.fetch_sub[ordering=Ordering.RELAXED](removed)
        self._shared[].pruning.store[ordering=Ordering.RELEASE](0)
        return pruned^
