"""A closable, intrusive, lock-free stack: pushes from any thread until one step closes it.

A Treiber stack whose nodes are the elements' own links. An element is a
handle (`_Linked`) to an allocation that never moves while the element lives,
such as a fiber record behind its `ArcPointer`, and that allocation embeds one
`_StackLink` for the element's own type. Pushing moves the handle into its own
link, so the stack holds the reference while the element is listed, and
installs the link's address as the head. Nothing is allocated per push or
per close, and each element may be listed on one stack, once.

The head word is the newest link's address, zero when empty, or an odd closed
marker. Elements leave only in whole lists: `close` swaps in the marker and
returns every element, and an exclusive `prune` detaches the list, drops the
elements its predicate rejects, and pushes the survivors back. Nothing pops
single links, so pushes are free of ABA: a push links to whatever head it read
and installs itself only if the head still holds that value, which is then a
listed link (possibly a reused address, but a live one) or zero.

The closed marker is `1 | tag << 1`; link addresses are even. The tag records
how the stack was closed, so a pruner that finds it closed can treat its
survivors as the closer treated the elements it received.

A close during a prune: the pruner holds the detached survivors while the
closer swaps the head and receives only what was pushed since the detach.
When the pruner then finds the marker, it does not push its survivors back but
returns them, with the tag, as orphans; the caller hands them to whatever the
closer did with its elements. No survivor is lost or seen twice.

Failing parties fail on a read: a push that finds the marker returns its
element without a read-modify-write, and so do a close of a closed stack and a
prune of an empty or closed one.

Memory ordering of each atomic operation:

- A push writes its link (the handle and the next address), then installs it
  with a compare-exchange that is RELEASE on success. Every change of the head
  is a read-modify-write, so the pushes form one release sequence, and the
  closer's or pruner's ACQUIRE read of the head synchronizes with every push
  before it: each link's contents are visible. Failure is RELAXED: it only
  reloads the head for the next attempt, and a closed marker read that way
  needs no ordering, since the pusher then keeps its element and touches
  nothing shared.
- `close` and the prune's detach take the list with a compare-exchange that is
  ACQUIRE on success (above) and RELAXED on failure (retry). Neither publishes
  anything: the marker and zero carry no data.
- The prune's splice of survivors is RELEASE on success, as a push, and
  RELAXED on failure.
- The pruning flag is a lock among pruners only: taken with ACQUIRE, released
  with RELEASE. Pushes and closes never wait for it; a pruner that loses skips
  its prune.
- `is_closed` loads the head with ACQUIRE, as a reader of the closer's
  decision.
- The links themselves are plain fields. A link is written only by the party
  that owns its element at that moment: the pusher before its RELEASE
  install, and the closer or pruner after its ACQUIRE detach.

The stack keeps no length: a shared counter beside the head would add a
second contended read-modify-write to every push. Owners that prune by size
count their own pushes (see `_Scope`).

Cost (`probes/race_primitives_cost.mojo`, O3, four cores, medians of five
runs, pushing copies of preallocated `ArcPointer`s against a `List` under
`_lock_cell`'s spin lock): a push and its share of a close cost 32 ns against
35 uncontended; with 2, 4, 8 and 16 threads pushing into one stack, 150, 137,
140 and 181 ns against 175, 412, 670 and 1,263, since pushers never wait for
a preempted holder. A first version that allocated a node per push cost 54 ns
uncontended.

Destroying the stack destroys every element still in it exactly once; it
requires that no other thread uses the stack.
"""
from std.atomic import Atomic, Ordering
from std.memory.alloc import unsafe_alloc
from std.os import abort

comptime _EMPTY = UInt64(0)


@always_inline
def _closed(head: UInt64) -> Bool:
    return Bool(head & 1)


struct _StackLink[T: Movable & Deinitable](Movable):
    """The stack's place in an element's allocation: the next link and the listed handle.

    Embedded once in the allocation an element's handle points to. While the
    element is listed, `held` is the stack's own handle to it.
    """
    var next: UInt64
    var held: Optional[Self.T]

    def __init__(out self):
        self.next = _EMPTY
        self.held = None


trait _Linked(Movable, Deinitable):
    """A handle to a stable allocation that embeds a `_StackLink` of this handle's type."""

    def _link_address(self) -> Int:
        """The address of the embedded link, fixed while any handle to it lives."""
        ...


struct _StackShared(Movable):
    """The head word and the pruners' flag, alone on one 64-byte line."""
    var head: Atomic[UInt64]
    var pruning: Atomic[UInt8]
    var _padding: Array[UInt8, 48]

    def __init__(out self):
        self.head = Atomic(_EMPTY)
        self.pruning = Atomic(UInt8(0))
        self._padding = Array[UInt8, 48](fill=0)


struct _Pruned[T: Movable & Deinitable](Movable):
    """What a prune did: elements it dropped, and survivors orphaned by a close with its tag."""
    var removed: Int
    var orphans: List[Self.T]
    var tag: UInt8

    def __init__(out self):
        self.removed = 0
        self.orphans = List[Self.T]()
        self.tag = 0


struct _ClosableStack[T: _Linked](Movable):
    """An intrusive lock-free stack of owned handles that closes once; see the module docstring.

    Parameters:
        T: The element, a handle whose allocation embeds its link.
    """
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
    def _link(address: UInt64) -> Pointer[_StackLink[Self.T], MutUntrackedOrigin]:
        return Pointer[_StackLink[Self.T], MutUntrackedOrigin](unsafe_from_address=Int(address))

    @always_inline
    @staticmethod
    def _unlist(address: UInt64) -> Self.T:
        """Take the stack's handle out of a detached link; `next` is rewritten by the next push."""
        return Self._link(address)[].held.take()

    @staticmethod
    def _drain(var head: UInt64) -> List[Self.T]:
        """Take every element of a detached chain, oldest first, in one allocation."""
        var count = 0
        var cursor = head
        while cursor != _EMPTY:
            count += 1
            cursor = Self._link(cursor)[].next
        var values = List[Self.T](unsafe_uninit_length=count)
        var index = count
        while head != _EMPTY:
            # Read the next link first: taking the handle may free this one.
            var next = Self._link(head)[].next
            index -= 1
            values.unsafe_ptr().unsafe_offset(index).unsafe_write(Self._unlist(head))
            head = next
        return values^

    @always_inline
    def push(self, var value: Self.T) -> Optional[Self.T]:
        """Push unless closed; a closed stack returns the element to the caller.

        The element must not already be listed on a stack.
        """
        var address = UInt64(value._link_address())
        var link = Self._link(address)
        if link[].held:
            abort("an element was pushed onto a stack twice")
        var head = self._shared[].head.load[ordering=Ordering.RELAXED]()
        if _closed(head):
            return Optional(value^)
        link[].held = Optional(value^)
        while True:
            link[].next = head
            if self._shared[].head.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELEASE](head, address):
                return None
            if _closed(head):
                return Optional(Self._unlist(address))

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
        return Self._drain(head)

    def is_closed(self) -> Bool:
        return _closed(self._shared[].head.load[ordering=Ordering.ACQUIRE]())

    def prune[keep: def(Self.T) thin -> Bool](self) -> _Pruned[Self.T]:
        """Drop the elements `keep` rejects; one pruner at a time, others skip.

        Survivors return to the stack in their order. If it closed during the
        prune, they are returned as orphans with the close's tag instead.

        Parameters:
            keep: Whether an element stays.
        """
        var pruned = _Pruned[Self.T]()
        if self._shared[].pruning.load[ordering=Ordering.RELAXED]() != 0:
            return pruned^
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
        # Survivors, newest first, relinked in their order; rejected elements dropped.
        var first = _EMPTY
        var last = _EMPTY
        var cursor = head
        while cursor != _EMPTY:
            var link = Self._link(cursor)
            var following = link[].next
            if keep(link[].held.value()):
                link[].next = _EMPTY
                if last == _EMPTY:
                    first = cursor
                else:
                    Self._link(last)[].next = cursor
                last = cursor
            else:
                pruned.removed += 1
                _ = Self._unlist(cursor)
            cursor = following
        if first != _EMPTY:
            var current = self._shared[].head.load[ordering=Ordering.RELAXED]()
            while True:
                if _closed(current):
                    # A failed splice linked the last survivor to the links
                    # then on top, which now belong to the closer: cut it.
                    Self._link(last)[].next = _EMPTY
                    pruned.orphans = Self._drain(first)
                    pruned.tag = UInt8((current >> 1) & 0x7F)
                    pruned.removed += len(pruned.orphans)
                    break
                Self._link(last)[].next = current
                if self._shared[].head.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELEASE](current, first):
                    break
        self._shared[].pruning.store[ordering=Ordering.RELEASE](0)
        return pruned^
