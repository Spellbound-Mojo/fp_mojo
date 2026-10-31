"""The per-worker local ring: one producer (its owner), many consumers.

After Cats Effect's `LocalQueue`: a fixed-capacity circular buffer with a
`tail` written only by the owner and a `head` word packing two tags, `steal`
(high 32 bits) and `real` (low 32 bits). `real` is the next element to take;
`steal` trails it while a thief copies a claimed range, so the owner never
overwrites slots that are still being moved out. Tags are 32-bit wrapping
counters (upstream uses 16-bit tags in a 32-bit word); the wider tags make the
compare-exchange ABA window 2**32 operations instead of 2**16.

Operations:

- `enqueue` (owner): write at `tail`. When full and no steal is in progress,
  claim half the queue by advancing both tags and move it to the external queue
  in batches; when full during a steal, push the one element externally.
- `dequeue` (owner): take at `real` with a compare-exchange against thieves.
- `steal_into` (the thief, which owns `dst`): claim half of the victim's
  elements by advancing `real` alone, move them into `dst`, then release by
  setting `steal` to the current `real`. The first stolen element is returned.
- `enqueue_batch_from` (owner): take up to one batch from the external queue.

Memory ordering of each atomic operation:

- Owner loads of `tail` are RELAXED: only the owner writes it.
- Owner stores of `tail` are RELEASE and thief loads of `tail` are ACQUIRE, so
  the contents of every slot below the loaded tail are visible to the thief.
- `enqueue` and `enqueue_batch_from` load `head` with ACQUIRE. It pairs with the
  thief's RELEASE compare-exchange that ends a steal, so the thief's moves out
  of the slots happen before the owner overwrites them.
- `dequeue` loads and compare-exchanges `head` RELAXED. Atomicity alone decides
  between the owner and a thief for slot `real`; the slot was written by the
  owner itself, and no thief touches a slot it has not claimed.
- The spill compare-exchange in `enqueue` is RELAXED for the same reason: no
  steal is in progress (`steal == real`), and the owner wrote every slot.
- Thief loads of `head` are RELAXED: the thief reads only slots below the tail
  it acquires, and `head` gates nothing else; a stale value fails the claim.
- The thief's claiming compare-exchange is ACQUIRE on success, which keeps its
  slot reads after the claim without relying on the absence of other writers.
- The thief's releasing compare-exchange is RELEASE on success (RELAXED on
  failure, which only reloads the owner's newer `real`): its moves out of the
  victim's slots happen before the owner's ACQUIRE load observes the new
  `steal` and reuses them.
- Before writing into `dst`, the thief loads `dst.head` with ACQUIRE, for the
  same reason as `enqueue`.

Ownership: each element moves in once and out once. A destroyed queue destroys
the elements in `[real, tail)`; destruction requires that no thread uses it.
"""
from std.atomic import Atomic, Ordering
from std.memory.alloc import unsafe_alloc
from .external_queue import _ExternalQueue
from .random import _Random


@always_inline
def _pack(steal: UInt32, real: UInt32) -> UInt64:
    return (UInt64(steal) << 32) | UInt64(real)


@always_inline
def _steal_tag(head: UInt64) -> UInt32:
    return UInt32(head >> 32)


@always_inline
def _real_tag(head: UInt64) -> UInt32:
    return UInt32(head & 0xFFFFFFFF)


struct _RingIndices(Movable):
    """The ring's head and tail words, each on its own 64-byte line."""
    var head: Atomic[UInt64]
    var _padding_after_head: Array[Int, 7]
    var tail: Atomic[UInt32]
    var _padding_after_tail: Array[Int, 15]

    def __init__(out self):
        self.head = Atomic(UInt64(0))
        self._padding_after_head = Array[Int, 7](fill=0)
        self.tail = Atomic(UInt32(0))
        self._padding_after_tail = Array[Int, 15](fill=0)


struct _LocalQueue[T: Movable & Deinitable, capacity: Int = 256, batch: Int = 32](Movable):
    """A fixed-capacity single-producer multi-consumer ring of owned elements.

    Parameters:
        T: The element type, moved between threads.
        capacity: A power of two from 4 through 2**30.
        batch: The spill and refill batch size, dividing `capacity // 2`.
    """
    comptime _mask = UInt32(Self.capacity - 1)
    comptime _half = UInt32(Self.capacity // 2)

    var _buffer: Pointer[Self.T, MutUntrackedOrigin]
    var _indices: Pointer[_RingIndices, MutUntrackedOrigin]

    def __init__(out self):
        comptime assert Self.capacity >= 4 and Self.capacity <= (1 << 30) and (Self.capacity & (Self.capacity - 1)) == 0, "capacity must be a power of two from 4 through 2**30"
        comptime assert Self.batch > 0 and (Self.capacity // 2) % Self.batch == 0, "batch must divide half the capacity"
        self._buffer = unsafe_alloc[Self.T](Self.capacity)
        self._indices = unsafe_alloc[_RingIndices](1, alignment=64)
        self._indices.unsafe_write(_RingIndices())

    def __deinit__(deinit self):
        var real = _real_tag(self._indices[].head.load[ordering=Ordering.RELAXED]())
        var tail = self._indices[].tail.load[ordering=Ordering.RELAXED]()
        while real != tail:
            self._slot(real).unsafe_deinit_pointee()
            real += 1
        self._buffer.unsafe_free()
        self._indices.unsafe_deinit_pointee()
        self._indices.unsafe_free()

    @always_inline
    def _slot(self, index: UInt32) -> Pointer[Self.T, MutUntrackedOrigin]:
        return self._buffer.unsafe_offset(Int(index & Self._mask))

    def enqueue(mut self, var item: Self.T, external: _ExternalQueue[Self.T], mut random: _Random):
        """Owner only: append, spilling half the ring to `external` when it is full."""
        var tail = self._indices[].tail.load[ordering=Ordering.RELAXED]()
        while True:
            var head = self._indices[].head.load[ordering=Ordering.ACQUIRE]()
            var steal = _steal_tag(head)
            if tail - steal < UInt32(Self.capacity):
                self._slot(tail).unsafe_write(item^)
                self._indices[].tail.store[ordering=Ordering.RELEASE](tail + 1)
                return
            var real = _real_tag(head)
            if steal != real:
                # A thief is moving entries out; the ring cannot release half now.
                external.push(item^, random)
                return
            var moved = real + Self._half
            if self._indices[].head.compare_exchange[success_ordering=Ordering.RELAXED, failure_ordering=Ordering.RELAXED](head, _pack(moved, moved)):
                external._push_ring(self._buffer, real, Int(Self._half), Self._mask, Self.batch, random)
            # Retry: either there is room now or the head changed under a thief.

    def dequeue(mut self) -> Optional[Self.T]:
        """Owner only: take the oldest element, or None when empty."""
        var tail = self._indices[].tail.load[ordering=Ordering.RELAXED]()
        var head = self._indices[].head.load[ordering=Ordering.RELAXED]()
        while True:
            var real = _real_tag(head)
            if real == tail:
                return None
            var steal = _steal_tag(head)
            var following = real + 1
            var desired = _pack(following, following) if steal == real else _pack(steal, following)
            if self._indices[].head.compare_exchange[success_ordering=Ordering.RELAXED, failure_ordering=Ordering.RELAXED](head, desired):
                return Optional(self._slot(real).unsafe_take_pointee())

    def steal_into(self, dst: Self) -> Optional[Self.T]:
        """Thief only, as the owner of `dst`: take half of this queue's elements.

        Both queues are borrowed immutably: the victim is shared with its owner
        and other thieves, and Mojo cannot express an exclusive `dst` taken from
        the same collection of rings. The protocol, not the borrow, gives the
        caller exclusive use of `dst`'s producer side.

        Returns the first stolen element and moves the rest into `dst`; None when
        this queue is empty, another steal is in progress, or `dst` is over half full.
        `dst` must be a different ring from this one.
        """
        var dst_tail = dst._indices[].tail.load[ordering=Ordering.RELAXED]()
        var dst_head = dst._indices[].head.load[ordering=Ordering.ACQUIRE]()
        if dst_tail - _steal_tag(dst_head) > Self._half:
            return None
        var head = self._indices[].head.load[ordering=Ordering.RELAXED]()
        var steal: UInt32
        var count: UInt32
        while True:
            steal = _steal_tag(head)
            var real = _real_tag(head)
            if steal != real:
                return None
            var tail = self._indices[].tail.load[ordering=Ordering.ACQUIRE]()
            count = tail - real
            count = count - count // 2
            if count == 0 or count > Self._half:
                # Empty, or a stale head whose claim would fail anyway.
                if count == 0:
                    return None
                head = self._indices[].head.load[ordering=Ordering.RELAXED]()
                continue
            if self._indices[].head.compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](head, _pack(steal, real + count)):
                break
        var first = self._slot(steal).unsafe_take_pointee()
        for i in range(UInt32(1), count):
            dst._slot(dst_tail + i - 1).unsafe_write(self._slot(steal + i).unsafe_take_pointee())
        var claimed = _pack(steal, steal + count)
        while True:
            var real = _real_tag(claimed)
            if self._indices[].head.compare_exchange[success_ordering=Ordering.RELEASE, failure_ordering=Ordering.RELAXED](claimed, _pack(real, real)):
                break
        if count > 1:
            dst._indices[].tail.store[ordering=Ordering.RELEASE](dst_tail + count - 1)
        return Optional(first^)

    def enqueue_batch_from(mut self, external: _ExternalQueue[Self.T], mut random: _Random) -> Optional[Self.T]:
        """Owner only: take up to one batch from `external`, returning its first element."""
        var tail = self._indices[].tail.load[ordering=Ordering.RELAXED]()
        var head = self._indices[].head.load[ordering=Ordering.ACQUIRE]()
        var free = Int(UInt32(Self.capacity) - (tail - _steal_tag(head)))
        var moved = 0
        var first = external._pop_into(self._buffer, tail, Self._mask, min(Self.batch, free + 1), random, moved)
        if moved > 0:
            self._indices[].tail.store[ordering=Ordering.RELEASE](tail + UInt32(moved))
        return first^

    def len(self) -> Int:
        """The number of queued elements; exact for the owner, a hint for others."""
        var head = self._indices[].head.load[ordering=Ordering.RELAXED]()
        var tail = self._indices[].tail.load[ordering=Ordering.RELAXED]()
        var count = tail - _real_tag(head)
        # Separate loads can straddle a dequeue; never report a wrapped count.
        return Int(count) if count <= UInt32(Self.capacity) else 0

    def is_empty(self) -> Bool:
        return self.len() == 0
