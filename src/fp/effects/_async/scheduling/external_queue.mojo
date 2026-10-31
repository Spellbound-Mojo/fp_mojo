"""The pool's external queue: overflow from local rings and work submitted from outside.

Striped after Cats Effect's `ScalQueue`: a power-of-two number of independent
FIFO stripes, each a standard-library `Deque` in a `_Cell` locked through the
shared borrowed guard (`_lock_cell` in `fp._internal.cells`, which spins briefly
and then yields). Stripes are stored inline, each with its lock and published
length on its own cache lines. Producers choose a random stripe, independently
for each batch; consumers scan from a random stripe. Order is FIFO within a
stripe only, as upstream.

Batching compared with upstream (checked against `LocalQueue.enqueue`,
`ScalQueue.offerAll`, and `WorkerThread.lookForWork` at the pinned commit): a
full upstream ring splits its released half into 4 arrays of 32, and
`offerAll` offers each array as one element to its own random stripe. A worker
that polls such an element moves the whole batch into its ring with
`enqueueBatch`, after `drainBatch` makes room. Here a spill moves each batch of
`batch` elements into one random stripe under one lock, as separate elements,
and `_LocalQueue.enqueue_batch_from` takes up to one batch from one stripe in
one step. A consumer that wants one element (`pop`) therefore takes one rather
than a whole batch, and a refill may join the end of one spilled batch with the
start of another in the same stripe; neither changes ownership or FIFO order
within a stripe.

Memory ordering:

- Element storage is only touched while holding a stripe's lock. The lock's
  ACQUIRE compare-exchange and RELEASE store order every push before every
  later pop of that stripe.
- Each stripe publishes its length in an `Atomic[Int]` so that consumers
  skip empty stripes without taking their locks. Stores (under the lock) and
  loads are RELAXED: the counter is a hint and never guards element memory, which
  the lock does. A push that happens before a `pop` starts is still found:
  coherence forbids the load from returning a value older than one that happens
  before it, so the stripe is seen nonempty unless another consumer emptied it.
  A pop that races with a concurrent push may miss it; callers that park must
  re-check after publishing their intent to park, with their own fence.

All operations borrow the queue immutably: it is shared, and its state changes
only under stripe locks or through atomics.

Ownership: every element moves in exactly once and out exactly once, or is
destroyed with the queue. Destruction requires that no other thread uses it.
"""
from std.atomic import Atomic, Ordering
from std.collections import Deque
from std.memory.alloc import unsafe_alloc
from std.os import abort
from fp._internal.cells import _Cell, _lock_cell
from .random import _Random


struct _Stripe[T: Movable & Deinitable](Movable):
    """One stripe: its lock, elements, and published length, padded from the next stripe."""
    var cell: _Cell[Deque[Self.T]]
    var length: Atomic[Int]
    var _padding: Array[Int, 8]

    def __init__(out self):
        self.cell = _Cell(Atomic(UInt8(0)), Optional(Deque[Self.T]()))
        self.length = Atomic(0)
        self._padding = Array[Int, 8](fill=0)


struct _ExternalQueue[T: Movable & Deinitable](Movable):
    """A many-producer many-consumer unbounded queue of owned elements."""
    var _stripes: Pointer[_Stripe[Self.T], MutUntrackedOrigin]
    var _count: Int

    def __init__(out self, stripes: Int):
        """Create at least `stripes` stripes, rounded up to a power of two.

        Args:
            stripes: The expected number of concurrent users, such as the worker count.
        """
        var count = 1
        while count < stripes:
            count *= 2
        self._count = count
        self._stripes = unsafe_alloc[_Stripe[Self.T]](count, alignment=64)
        for i in range(count):
            self._stripes.unsafe_offset(i).unsafe_write(_Stripe[Self.T]())

    def __deinit__(deinit self):
        # Destroying the stripes destroys every element left in them, once.
        for i in range(self._count):
            self._stripes.unsafe_offset(i).unsafe_deinit_pointee()
        self._stripes.unsafe_free()

    @always_inline
    def stripes(self) -> Int:
        return self._count

    @always_inline
    def _stripe(self, index: Int) -> ref[MutUntrackedOrigin] _Stripe[Self.T]:
        return self._stripes[unsafe_offset=index]

    def push(self, var item: Self.T, mut random: _Random):
        """Append one element to a random stripe."""
        ref stripe = self._stripe(random.below(self._count))
        var guard = _lock_cell(stripe.cell)
        guard.cell[].slot.value().append(item^)
        stripe.length.store[ordering=Ordering.RELAXED](len(guard.cell[].slot.value()))

    def _push_ring(self, buffer: Pointer[Self.T, MutUntrackedOrigin], start: UInt32, count: Int, mask: UInt32, batch: Int, mut random: _Random):
        """Move `count` initialized ring slots from `start` into stripes, `batch` per lock.

        Each batch goes to its own random stripe. The caller has claimed the
        slots exclusively; they are uninitialized afterwards.
        """
        var offset = 0
        while offset < count:
            ref stripe = self._stripe(random.below(self._count))
            var end = min(offset + batch, count)
            var guard = _lock_cell(stripe.cell)
            for i in range(offset, end):
                var slot = Int((start + UInt32(i)) & mask)
                guard.cell[].slot.value().append(buffer.unsafe_offset(slot).unsafe_take_pointee())
            stripe.length.store[ordering=Ordering.RELAXED](len(guard.cell[].slot.value()))
            offset = end

    def pop(self, mut random: _Random) -> Optional[Self.T]:
        """Take the oldest element of the first nonempty stripe, scanning from a random one."""
        var start = random.below(self._count)
        for i in range(self._count):
            ref stripe = self._stripe((start + i) & (self._count - 1))
            if stripe.length.load[ordering=Ordering.RELAXED]() == 0:
                continue
            var guard = _lock_cell(stripe.cell)
            var length = len(guard.cell[].slot.value())
            if length == 0:
                continue
            stripe.length.store[ordering=Ordering.RELAXED](length - 1)
            try:
                return Optional(guard.cell[].slot.value().popleft())
            except:
                abort("external queue stripe emptied under its lock")
        return None

    def _pop_into(self, buffer: Pointer[Self.T, MutUntrackedOrigin], start: UInt32, mask: UInt32, limit: Int, mut random: _Random, mut moved: Int) -> Optional[Self.T]:
        """Take up to `limit` elements of one stripe: return the first, write the rest at `start`.

        `moved` receives how many ring slots were written, at most `limit - 1`.
        The caller owns those uninitialized slots exclusively.
        """
        moved = 0
        var origin = random.below(self._count)
        for i in range(self._count):
            ref stripe = self._stripe((origin + i) & (self._count - 1))
            if stripe.length.load[ordering=Ordering.RELAXED]() == 0:
                continue
            var guard = _lock_cell(stripe.cell)
            var length = len(guard.cell[].slot.value())
            if length == 0:
                continue
            var take = min(length, limit)
            stripe.length.store[ordering=Ordering.RELAXED](length - take)
            try:
                var head = guard.cell[].slot.value().popleft()
                for j in range(1, take):
                    var slot = Int((start + UInt32(j - 1)) & mask)
                    buffer.unsafe_offset(slot).unsafe_write(guard.cell[].slot.value().popleft())
                moved = take - 1
                return Optional(head^)
            except:
                abort("external queue stripe emptied under its lock")
        return None

    def is_empty(self) -> Bool:
        """Whether every stripe's published length is zero; a hint under concurrency."""
        for i in range(self._count):
            if self._stripe(i).length.load[ordering=Ordering.RELAXED]() != 0:
                return False
        return True

    def approximate_len(self) -> Int:
        var total = 0
        for i in range(self._count):
            total += self._stripe(i).length.load[ordering=Ordering.RELAXED]()
        return total
