"""The diagnostic slots of a root's live fibers, without a lock.

`Driver.fibers()` names each live fiber by a slot that stays fixed while the
fiber lives and is reused once it completes (`FiberInfo`). The slots come from
a lock-free allocator: a stack of free indices plus a high-water count of the
indices ever handed out. Each slot's entry records the fiber's owner slot,
whether it is draining its children, and the address of its task's atomic
scheduling state, from which a snapshot reads runnable or suspended.

Starting a fiber pops a free index (one compare-exchange) or takes a fresh one
(one `fetch_add`), then publishes its entry; ending it clears the entry and
pushes the index back (one compare-exchange). Nothing takes a lock. The head of
the free stack is one word shared by every fiber start and end under the root:
a known contention point for the work-stealing pool (13c), which can shard
the slots per worker.

Representation:

- Entries live in chunks of 64, 128, 256, ... entries that never move until
  the table is destroyed, so an index stays addressable while other threads
  grow the table. A chunk is allocated by the first thread that needs it and
  installed with a compare-exchange; a thread that loses frees its own.
- The free stack's head packs a 32-bit tag (high half) and the top index plus
  one (low half, zero when empty). Each entry holds the next free index plus
  one. Every successful push and pop increments the tag, so a pop whose read
  of the top's `next` went stale (the top was popped and pushed back between
  its load and its compare-exchange) fails unless exactly 2**32 other pushes
  and pops completed in that window, which is the accepted ABA bound (S4's
  local ring makes the same trade with its 32-bit tags).

Memory ordering of each atomic operation:

- A chunk's address is installed with ACQUIRE_RELEASE and loaded with ACQUIRE:
  the RELEASE publishes the chunk's zeroed entries, and a losing installer's
  ACQUIRE sees the winner's.
- The high-water count is incremented RELAXED: it only hands out distinct
  indices. Snapshots load it ACQUIRE; the entries' own RELEASE stores carry
  the data they read.
- A pop loads the head with ACQUIRE, so the popped index's `next`, written
  before the push that released it, is visible; its compare-exchange is
  ACQUIRE on success and failure for the same reason on the retry.
- A push stores the entry's `next` RELAXED and installs the head with a RELEASE
  compare-exchange (RELAXED failure), publishing that `next` and everything
  the releasing fiber did to the entry before the next popper.
- Registering stores the owner and the draining flag RELAXED, then the task
  state's address with RELEASE; a snapshot loads the address with ACQUIRE
  and then the other fields. Draining is stored RELAXED: it is a diagnostic
  flag and its readers order themselves through the address. Clearing the
  address is RELEASE, before the push.

Snapshot safety: a snapshot dereferences the task-state address of every
registered entry. It must not race with that fiber finishing and freeing the
state. `Driver.fibers()` meets this by running between polls on the thread
that drives the root, the only thread that runs its fibers on the
current-thread profile (Pass 13 decision 3). A work-stealing runtime's fiber
dump needs per-worker snapshots or quiescence.
"""
from std.atomic import Atomic, Ordering
from std.bit import count_leading_zeros
from std.memory.alloc import unsafe_alloc
from std.os import abort

comptime _BASE_SHIFT = 6
comptime _CHUNK_LIMIT = 26


struct _SlotEntry(Movable):
    """One slot: the live fiber's task-state address (zero when free), owner, draining flag and free-list link."""
    var task: Atomic[UInt64]
    var owner: Atomic[Int]
    var draining: Atomic[UInt8]
    var next: Atomic[UInt32]

    def __init__(out self):
        self.task = Atomic(UInt64(0))
        self.owner = Atomic(0)
        self.draining = Atomic(UInt8(0))
        self.next = Atomic(UInt32(0))


struct _SlotsShared(Movable):
    var head: Atomic[UInt64]
    var high: Atomic[Int]

    def __init__(out self):
        self.head = Atomic(UInt64(0))
        self.high = Atomic(0)


@fieldwise_init
struct _SlotView(Copyable):
    """One registered slot as a snapshot read it."""
    var index: Int
    var owner: Int
    var draining: Bool
    var task: UInt64


@always_inline
def _locate(index: Int) -> Tuple[Int, Int]:
    var shifted = UInt64(index + (1 << _BASE_SHIFT))
    var chunk = 63 - Int(count_leading_zeros(shifted)) - _BASE_SHIFT
    return (chunk, Int(shifted) - (1 << (_BASE_SHIFT + chunk)))


struct _FiberSlots(Movable):
    """Lock-free slot allocation and registration for one root; see the module docstring."""
    var _shared: Pointer[_SlotsShared, MutUntrackedOrigin]
    # The chunk directory: chunk k holds 64 << k entries, or is zero.
    var _chunks: Pointer[Atomic[UInt64], MutUntrackedOrigin]

    def __init__(out self):
        self._shared = unsafe_alloc[_SlotsShared](1, alignment=64)
        self._shared.unsafe_write(_SlotsShared())
        self._chunks = unsafe_alloc[Atomic[UInt64]](_CHUNK_LIMIT)
        for k in range(_CHUNK_LIMIT):
            self._chunks.unsafe_offset(k).unsafe_write(Atomic(UInt64(0)))

    def __deinit__(deinit self):
        for k in range(_CHUNK_LIMIT):
            var address = self._chunks.unsafe_offset(k)[].load[ordering=Ordering.RELAXED]()
            if address:
                var chunk = Pointer[_SlotEntry, MutUntrackedOrigin](unsafe_from_address=Int(address))
                for i in range(1 << (_BASE_SHIFT + k)):
                    chunk.unsafe_offset(i).unsafe_deinit_pointee()
                chunk.unsafe_free()
            self._chunks.unsafe_offset(k).unsafe_deinit_pointee()
        self._chunks.unsafe_free()
        self._shared.unsafe_deinit_pointee()
        self._shared.unsafe_free()

    def _entry(self, index: Int) -> Pointer[_SlotEntry, MutUntrackedOrigin]:
        """The entry of an index below the high-water count, growing the table if needed."""
        var place = _locate(index)
        if place[0] >= _CHUNK_LIMIT:
            abort("fiber slots exhausted")
        var directory = self._chunks.unsafe_offset(place[0])
        var address = directory[].load[ordering=Ordering.ACQUIRE]()
        if not address:
            var size = 1 << (_BASE_SHIFT + place[0])
            var chunk = unsafe_alloc[_SlotEntry](size)
            for i in range(size):
                chunk.unsafe_offset(i).unsafe_write(_SlotEntry())
            var expected = UInt64(0)
            if directory[].compare_exchange[failure_ordering=Ordering.ACQUIRE, success_ordering=Ordering.ACQUIRE_RELEASE](expected, UInt64(Int(chunk))):
                address = UInt64(Int(chunk))
            else:
                for i in range(size):
                    chunk.unsafe_offset(i).unsafe_deinit_pointee()
                chunk.unsafe_free()
                address = expected
        return Pointer[_SlotEntry, MutUntrackedOrigin](unsafe_from_address=Int(address)).unsafe_offset(place[1])

    def _pop(self) -> Int:
        var head = self._shared[].head.load[ordering=Ordering.ACQUIRE]()
        while True:
            var top = Int(head & 0xFFFFFFFF)
            if top == 0:
                return self._shared[].high.fetch_add[ordering=Ordering.RELAXED](1)
            var following = UInt64(self._entry(top - 1)[].next.load[ordering=Ordering.RELAXED]())
            var next = (((head >> 32) + 1) << 32) | following
            if self._shared[].head.compare_exchange[failure_ordering=Ordering.ACQUIRE, success_ordering=Ordering.ACQUIRE](head, next):
                return top - 1

    def _push(self, index: Int):
        var entry = self._entry(index)
        var head = self._shared[].head.load[ordering=Ordering.RELAXED]()
        while True:
            entry[].next.store[ordering=Ordering.RELAXED](UInt32(head & 0xFFFFFFFF))
            var next = (((head >> 32) + 1) << 32) | UInt64(index + 1)
            if self._shared[].head.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELEASE](head, next):
                return

    def register(self, owner: Int, task: UInt64) -> Int:
        """Take a slot for a live fiber; returns its index from 1 (0 is the root program)."""
        var index = self._pop()
        var entry = self._entry(index)
        entry[].owner.store[ordering=Ordering.RELAXED](owner)
        entry[].draining.store[ordering=Ordering.RELAXED](0)
        entry[].task.store[ordering=Ordering.RELEASE](task)
        return index + 1

    def set_draining(self, slot: Int):
        self._entry(slot - 1)[].draining.store[ordering=Ordering.RELAXED](1)

    def release(self, slot: Int):
        """Free a completed fiber's slot for reuse."""
        self._entry(slot - 1)[].task.store[ordering=Ordering.RELEASE](0)
        self._push(slot - 1)

    def high_water(self) -> Int:
        """Slots ever handed out; the bound of every index."""
        return self._shared[].high.load[ordering=Ordering.ACQUIRE]()

    def snapshot(self) -> List[_SlotView]:
        """The registered slots in index order; see the module docstring for when it is safe."""
        var views = List[_SlotView]()
        for index in range(self.high_water()):
            var entry = self._entry(index)
            var task = entry[].task.load[ordering=Ordering.ACQUIRE]()
            if task:
                views.append(_SlotView(index + 1, entry[].owner.load[ordering=Ordering.RELAXED](), entry[].draining.load[ordering=Ordering.RELAXED]() != 0, task))
        return views^
