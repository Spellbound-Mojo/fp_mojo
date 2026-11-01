"""The diagnostic slots of a root's live fibers, without a lock.

`Driver.fibers()` names each live fiber by a slot that stays fixed while the
fiber lives and is reused once it completes (`FiberInfo`). The slots come from
a lock-free allocator: a stack of free indices plus a high-water count of the
indices ever handed out. Each slot's entry records the fiber's owner slot,
whether it is draining its children, and the address of its task's atomic
scheduling state, from which a snapshot reads runnable or suspended.

Starting a fiber pops a free index (one compare-exchange) or takes a fresh one
(one `fetch_add`), then publishes its entry; ending it clears the entry and
pushes the index back (one compare-exchange). Nothing takes a lock.

The free indices are sharded: one free stack per shard, each head on its own
cache line, and the caller names its shard (a work-stealing pool passes the
running worker's index; the current-thread profile has one shard, which is
the unsharded allocator). A start pops from its own shard, and a start that
finds its shard empty scans the others before taking a fresh index, so an
index freed on one worker is reused by a start on another and the table stays
bounded by the peak number of live fibers. Starts and ends on different
workers therefore touch different words, except for that scan.

Representation:

- Entries live in chunks of 64, 128, 256, ... entries that never move until
  the table is destroyed, so an index stays addressable while other threads
  grow the table. A chunk is allocated by the first thread that needs it and
  installed with a compare-exchange; a thread that loses frees its own.
- Each shard's free-stack head packs a 32-bit tag (high half) and the top
  index plus one (low half, zero when empty). Each entry holds the next free index plus
  one. Every successful push and pop increments the tag, so a pop whose read
  of the top's `next` went stale (the top was popped and pushed back between
  its load and its compare-exchange) fails unless exactly 2**32 other pushes
  and pops completed in that window, which is the accepted ABA bound (the work-stealing
  `_LocalQueue` makes the same trade with its 32-bit tags).

Memory ordering of each atomic operation:

- A chunk's address is installed with ACQUIRE_RELEASE and loaded with ACQUIRE:
  the RELEASE publishes the chunk's zeroed entries, and a losing installer's
  ACQUIRE sees the winner's.
- The high-water count, the first padded word of the shared allocation, is
  incremented RELAXED: it only hands out distinct indices. Snapshots load it ACQUIRE; the entries' own RELEASE stores carry
  the data they read.
- A pop, from the caller's shard or another, loads the head with ACQUIRE, so the popped index's `next`, written
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
current-thread profile.

A table created shared (`share_snapshots`, before the root is shared with
another thread) may be snapshotted from any thread at any time, as
`Runtime.fibers()` does. A reader count makes it safe, with a Dekker
handshake between a snapshot and a releasing fiber:

- A snapshot increments `readers` (SEQUENTIAL), loads each entry's address
  (SEQUENTIAL), dereferences the task state of every nonzero one (ACQUIRE),
  and decrements `readers` (RELEASE) after its last dereference.
- A release clears the entry's address (SEQUENTIAL), then loads `readers`
  (SEQUENTIAL); while it reads nonzero it spins, with ACQUIRE loads, before
  the fiber goes on to finish and free its task.

In the single total order of the sequentially consistent operations, either
the release's load follows the snapshot's increment, and the release waits
for the snapshot to finish, or the snapshot's load of the address follows the
release's clear and reads zero, so the snapshot never touches that task. A
release waits at most for snapshots in progress; snapshots that keep starting
from many threads at once can delay fiber completion, which is the cost of a
diagnostic read. The `shared` word is stored RELAXED before the table is
shared and loaded RELAXED: the root's publication to other threads orders it.
Tables that are not shared keep the RELEASE clear and pay nothing.
"""
from std.atomic import Atomic, Ordering
from std.bit import count_leading_zeros
from std.memory.alloc import unsafe_alloc
from std.os import abort

comptime _BASE_SHIFT = 6
comptime _CHUNK_LIMIT = 26
comptime _HEADS = 3
"""Padded words before the shard heads: the high-water count, the readers and the shared flag."""


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


struct _PaddedWord(Movable):
    """One atomic word alone on a 64-byte line: the high-water count or a shard's free-stack head."""
    var value: Atomic[UInt64]
    var _padding: Array[Int, 7]

    def __init__(out self):
        self.value = Atomic(UInt64(0))
        self._padding = Array[Int, 7](fill=0)


@fieldwise_init
struct _SlotView(Copyable):
    """One registered slot as a snapshot read it, with its task's scheduling state."""
    var index: Int
    var owner: Int
    var draining: Bool
    var state: UInt8


@always_inline
def _locate(index: Int) -> Tuple[Int, Int]:
    var shifted = UInt64(index + (1 << _BASE_SHIFT))
    var chunk = 63 - Int(count_leading_zeros(shifted)) - _BASE_SHIFT
    return (chunk, Int(shifted) - (1 << (_BASE_SHIFT + chunk)))


struct _FiberSlots(Movable):
    """Lock-free slot allocation and registration for one root; see the module docstring."""
    # Word 0 is the high-water count, word 1 the snapshot readers, word 2 the
    # shared flag; word 3 + k is shard k's free-stack head.
    var _shared: Pointer[_PaddedWord, MutUntrackedOrigin]
    var _shards: Int
    # The chunk directory: chunk k holds 64 << k entries, or is zero.
    var _chunks: Pointer[Atomic[UInt64], MutUntrackedOrigin]

    def __init__(out self, shards: Int = 1):
        if shards < 1:
            abort("fiber slots need at least one shard")
        self._shards = shards
        self._shared = unsafe_alloc[_PaddedWord](shards + _HEADS, alignment=64)
        for i in range(shards + _HEADS):
            self._shared.unsafe_offset(i).unsafe_write(_PaddedWord())
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
        for i in range(self._shards + _HEADS):
            self._shared.unsafe_offset(i).unsafe_deinit_pointee()
        self._shared.unsafe_free()

    @always_inline
    def _high(self) -> ref[MutUntrackedOrigin] Atomic[UInt64]:
        return self._shared[unsafe_offset=0].value

    @always_inline
    def _readers(self) -> ref[MutUntrackedOrigin] Atomic[UInt64]:
        return self._shared[unsafe_offset=1].value

    @always_inline
    def _shared_flag(self) -> ref[MutUntrackedOrigin] Atomic[UInt64]:
        return self._shared[unsafe_offset=2].value

    @always_inline
    def _head(self, shard: Int) -> ref[MutUntrackedOrigin] Atomic[UInt64]:
        return self._shared[unsafe_offset=_HEADS + shard].value

    def share_snapshots(self):
        """Allow snapshots from any thread; before the table is shared (see the module docstring)."""
        self._shared_flag().store[ordering=Ordering.RELAXED](1)

    @always_inline
    def shards(self) -> Int:
        return self._shards

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

    def _pop_from(self, shard: Int) -> Int:
        """Pop a free index from one shard's stack; -1 when it is empty."""
        var head = self._head(shard).load[ordering=Ordering.ACQUIRE]()
        while True:
            var top = Int(head & 0xFFFFFFFF)
            if top == 0:
                return -1
            var following = UInt64(self._entry(top - 1)[].next.load[ordering=Ordering.RELAXED]())
            var next = (((head >> 32) + 1) << 32) | following
            if self._head(shard).compare_exchange[failure_ordering=Ordering.ACQUIRE, success_ordering=Ordering.ACQUIRE](head, next):
                return top - 1

    def _pop(self, shard: Int) -> Int:
        var index = self._pop_from(shard)
        if index >= 0:
            return index
        # Reuse an index another shard freed before growing the table.
        for offset in range(1, self._shards):
            index = self._pop_from((shard + offset) % self._shards)
            if index >= 0:
                return index
        return Int(self._high().fetch_add[ordering=Ordering.RELAXED](1))

    def _push(self, index: Int, shard: Int):
        var entry = self._entry(index)
        var head = self._head(shard).load[ordering=Ordering.RELAXED]()
        while True:
            entry[].next.store[ordering=Ordering.RELAXED](UInt32(head & 0xFFFFFFFF))
            var next = (((head >> 32) + 1) << 32) | UInt64(index + 1)
            if self._head(shard).compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELEASE](head, next):
                return

    def register(self, owner: Int, task: UInt64, shard: Int = 0) -> Int:
        """Take a slot for a live fiber, preferring `shard`'s free indices; returns its index from 1 (0 is the root program)."""
        var index = self._pop(shard)
        var entry = self._entry(index)
        entry[].owner.store[ordering=Ordering.RELAXED](owner)
        entry[].draining.store[ordering=Ordering.RELAXED](0)
        entry[].task.store[ordering=Ordering.RELEASE](task)
        return index + 1

    def set_draining(self, slot: Int):
        self._entry(slot - 1)[].draining.store[ordering=Ordering.RELAXED](1)

    def release(self, slot: Int, shard: Int = 0):
        """Free a completed fiber's slot for reuse, onto `shard`'s free stack."""
        var entry = self._entry(slot - 1)
        if self._shared_flag().load[ordering=Ordering.RELAXED]() == 0:
            entry[].task.store[ordering=Ordering.RELEASE](0)
        else:
            # The Dekker handshake with snapshots (module docstring).
            entry[].task.store[ordering=Ordering.SEQUENTIAL](0)
            if self._readers().load[ordering=Ordering.SEQUENTIAL]() != 0:
                while self._readers().load[ordering=Ordering.ACQUIRE]() != 0:
                    pass
        self._push(slot - 1, shard)

    def high_water(self) -> Int:
        """Slots ever handed out; the bound of every index."""
        return Int(self._high().load[ordering=Ordering.ACQUIRE]())

    def snapshot(self) -> List[_SlotView]:
        """The registered slots in index order with their tasks' states; see the module docstring for when it is safe."""
        var views = List[_SlotView]()
        var shared = self._shared_flag().load[ordering=Ordering.RELAXED]() != 0
        if shared:
            _ = self._readers().fetch_add[ordering=Ordering.SEQUENTIAL](1)
        for index in range(self.high_water()):
            var entry = self._entry(index)
            var task: UInt64
            if shared:
                task = entry[].task.load[ordering=Ordering.SEQUENTIAL]()
            else:
                task = entry[].task.load[ordering=Ordering.ACQUIRE]()
            if task:
                var state = Pointer[Atomic[UInt8], MutUntrackedOrigin](unsafe_from_address=Int(task))[].load[ordering=Ordering.ACQUIRE]()
                views.append(_SlotView(index + 1, entry[].owner.load[ordering=Ordering.RELAXED](), entry[].draining.load[ordering=Ordering.RELAXED]() != 0, state))
        if shared:
            # After the last dereference: a waiting release may now free its task.
            _ = self._readers().fetch_sub[ordering=Ordering.RELEASE](1)
        return views^
