"""The per-worker timer heap: changed by its owner, canceled and stolen from anywhere.

After Cats Effect's `TimerHeap`. Only the owning worker inserts, fires, and
restructures. Any thread may cancel a timer through its ticket, and other
workers may take expired timers while searching for work. A cross-thread
cancellation only marks the node and counts it; the owner removes marked nodes
lazily and packs the heap when counted cancellations reach half its length.

Representation (where it departs from upstream):

- Upstream's nodes are garbage-collected objects whose callback field is
  cleared with plain writes; a duplicate run of an idempotent callback is
  harmless there. Here a payload is a move-only value that must leave the heap
  exactly once, so each node has an atomic state word, `generation << 3 | state`,
  and one compare-exchange from PENDING to CLAIMED picks the single owner of the
  payload among firing, stealing, and cancellation.
- Nodes live in generation-checked slots, the scheme of the wake registry's
  `_Ticket`: a ticket names a slot and its generation, and a recycled slot has a
  new generation, so a late cancellation fails instead of touching a reused
  slot. Generations are checked with `_next_generation` and limited to 61 bits.
- Slots, payloads, and heap entries live in chunks that never move or shrink
  until the heap is destroyed (`_StableChunks`). Thieves and cancelers may read
  them while the owner grows or reorders the heap without reclamation schemes.
- Heap entries are `Atomic[UInt32]` slot indices, so a thief's walk over the
  array while the owner sifts is a set of racing atomic reads, not a data race.
  A walk may miss or revisit a node; the state word prevents a double take. The
  owner sifts over private contiguous copies of the entries and their deadlines
  and writes each move through to the shared array; reading deadlines through
  the nodes made sifting four times slower than a standard `BinaryHeap`.
- Ties between equal deadlines are not ordered (as upstream).

States: FREE (on the free list), PENDING (in the heap with its payload),
CLAIMED (a winner is moving the payload out), FIRED or CANCELED (payload gone,
entry may still be in the heap). The owner recycles a slot only after its entry
has left the heap and its state is FIRED or CANCELED; a slot still CLAIMED is
kept on a draining list and recycled later.

Memory ordering of each atomic operation:

- `insert` writes the payload, then stores the deadline and the PENDING state
  with RELEASE. A claimer's ACQUIRE compare-exchange (cancellation, stealing)
  therefore sees the payload. The owner's own claims are RELAXED: it wrote it.
- A claimer that is not the owner stores FIRED or CANCELED with RELEASE after
  moving the payload out; the owner loads states with ACQUIRE before recycling
  a slot, so the move out happens before the slot's next payload is written.
  Recycling stores FREE with a new generation RELAXED: no thread acts on FREE,
  and the generation change alone makes stale claims fail.
- Heap entries are stored with RELEASE and loaded by thieves with ACQUIRE, and
  the published length likewise, so a thief that reads a slot index also sees
  the chunk holding it. The owner never reads the shared entries back.
- Thieves load the deadline with ACQUIRE after the state. If the owner has
  recycled the slot meanwhile, the newer deadline it reads was stored (RELEASE)
  after the old PENDING state was left, so the thief's claim of that old
  state word must fail; a stale deadline never authorizes a claim.
- The owner stores the root's deadline (or UInt64.MAX when empty) RELAXED
  whenever the root changes, and thieves load it RELAXED before walking. It is
  a hint: a stale value only skips a steal the owner will fire itself, or
  starts a walk that finds nothing; the walk's own loads carry the ordering.
- The cancellation counter is incremented RELAXED before the RELEASE store of
  CANCELED; the owner's ACQUIRE load of CANCELED then also sees the increment,
  which keeps `accounted <= counter`. The owner reads the counter RELAXED: it
  only decides when to pack, and every packed node is checked individually.

Ownership: each payload is moved in once and out once (fired, stolen, or
canceled), or destroyed with the heap. Destruction requires that no other thread
uses the heap or holds a claim in progress.
"""
from std.atomic import Atomic, Ordering
from std.bit import count_leading_zeros
from std.memory.alloc import unsafe_alloc
from std.os import abort
from fp._internal.waking import _Ticket, _next_generation

comptime _FREE = UInt64(0)
comptime _PENDING = UInt64(1)
comptime _CLAIMED = UInt64(2)
comptime _FIRED = UInt64(3)
comptime _CANCELED = UInt64(4)
comptime _STATE_MASK = UInt64(7)
comptime _GENERATION_LIMIT = UInt64(1) << 61


@always_inline
def _word(generation: UInt64, state: UInt64) -> UInt64:
    return (generation << 3) | state


struct _StableChunks[T: AnyType](Movable):
    """Indexable storage in chunks of 64, 128, 256, ... elements that never move.

    Only one thread grows it; other threads may address any index below a
    capacity that was published to them. The caller initializes and destroys
    elements; destruction frees only memory.
    """
    comptime _base_shift = 6
    comptime _chunk_limit = 26
    var _addresses: Array[Int, Self._chunk_limit]
    var _chunks: Int
    var _capacity: Int

    def __init__(out self):
        self._addresses = Array[Int, Self._chunk_limit](fill=0)
        self._chunks = 0
        self._capacity = 0

    def __deinit__(deinit self):
        for k in range(self._chunks):
            Pointer[Self.T, MutUntrackedOrigin](unsafe_from_address=self._addresses[k]).unsafe_free()

    @always_inline
    def capacity(self) -> Int:
        return self._capacity

    def grow(mut self) -> Int:
        """Allocate the next chunk and return the new capacity."""
        if self._chunks == Self._chunk_limit:
            abort("timer storage exhausted")
        var size = 1 << (Self._base_shift + self._chunks)
        self._addresses[self._chunks] = Int(unsafe_alloc[Self.T](size))
        self._chunks += 1
        self._capacity += size
        return self._capacity

    @always_inline
    def ptr(self, index: Int) -> Pointer[Self.T, MutUntrackedOrigin]:
        var shifted = UInt64(index + (1 << Self._base_shift))
        var chunk = 63 - Int(count_leading_zeros(shifted)) - Self._base_shift
        var offset = Int(shifted) - (1 << (Self._base_shift + chunk))
        return Pointer[Self.T, MutUntrackedOrigin](unsafe_from_address=self._addresses.unsafe_get(chunk)).unsafe_offset(offset)


struct _TimerNode(Movable):
    var state: Atomic[UInt64]
    var deadline: Atomic[UInt64]

    def __init__(out self):
        self.state = Atomic(_word(1, _FREE))
        self.deadline = Atomic(UInt64(0))


struct _HeapShared(Movable):
    """The words other threads touch, each on its own 64-byte line."""
    var earliest: Atomic[UInt64]
    var _padding_after_earliest: Array[Int, 7]
    var size: Atomic[Int]
    var _padding_after_size: Array[Int, 7]
    var canceled: Atomic[UInt64]
    var _padding_after_canceled: Array[Int, 7]

    def __init__(out self):
        self.earliest = Atomic(UInt64.MAX)
        self._padding_after_earliest = Array[Int, 7](fill=0)
        self.size = Atomic(0)
        self._padding_after_size = Array[Int, 7](fill=0)
        self.canceled = Atomic(UInt64(0))
        self._padding_after_canceled = Array[Int, 7](fill=0)


struct _TimerHeap[T: Movable & Deinitable](Movable):
    """A binary min-heap of owned payloads keyed by deadline (UInt64 ticks)."""
    var _nodes: _StableChunks[_TimerNode]
    var _payloads: _StableChunks[Self.T]
    var _entries: _StableChunks[Atomic[UInt32]]
    """The heap array that thieves walk: slot indices by position."""
    var _order: List[UInt32]
    """The owner's copy of `_entries`, read without atomics."""
    var _keys: List[UInt64]
    """Deadlines by position, so that sifting never leaves contiguous memory."""
    var _positions: List[Int]
    """Heap positions by slot, -1 outside the heap, for immediate owner cancellation."""
    var _slots: Int
    var _length: Int
    var _free: List[Int]
    var _draining: List[Int]
    var _accounted: UInt64
    var _shared: Pointer[_HeapShared, MutUntrackedOrigin]

    def __init__(out self):
        self._nodes = _StableChunks[_TimerNode]()
        self._payloads = _StableChunks[Self.T]()
        self._entries = _StableChunks[Atomic[UInt32]]()
        self._order = List[UInt32]()
        self._keys = List[UInt64]()
        self._positions = List[Int]()
        self._slots = 0
        self._length = 0
        self._free = List[Int]()
        self._draining = List[Int]()
        self._accounted = 0
        self._shared = unsafe_alloc[_HeapShared](1, alignment=64)
        self._shared.unsafe_write(_HeapShared())

    def __deinit__(deinit self):
        for slot in range(self._slots):
            if self._nodes.ptr(slot)[].state.load[ordering=Ordering.RELAXED]() & _STATE_MASK == _PENDING:
                self._payloads.ptr(slot).unsafe_deinit_pointee()
        self._shared.unsafe_deinit_pointee()
        self._shared.unsafe_free()

    # Owner operations.

    def insert(mut self, deadline: UInt64, var payload: Self.T) -> _Ticket:
        """Owner only: schedule `payload` at `deadline` and return its cancellation ticket."""
        self.pack_if_needed()
        var slot = self._allocate()
        var node = self._nodes.ptr(slot)
        var generation = node[].state.load[ordering=Ordering.RELAXED]() >> 3
        self._payloads.ptr(slot).unsafe_write(payload^)
        node[].deadline.store[ordering=Ordering.RELEASE](deadline)
        node[].state.store[ordering=Ordering.RELEASE](_word(generation, _PENDING))
        if self._length == self._entries.capacity():
            var first = self._entries.capacity()
            var end = self._entries.grow()
            for i in range(first, end):
                self._entries.ptr(i).unsafe_write(Atomic(UInt32(0)))
        var position = self._length
        self._length += 1
        self._order.append(UInt32(slot))
        self._keys.append(deadline)
        self._sift_up(position, UInt32(slot), deadline)
        self._shared[].size.store[ordering=Ordering.RELEASE](self._length)
        return _Ticket(slot, generation)

    def poll_expired(mut self, now: UInt64) -> Optional[Self.T]:
        """Owner only: remove and return the earliest payload due at `now`, if any."""
        while self._length > 0:
            var slot = Int(self._order.unsafe_get(0))
            var node = self._nodes.ptr(slot)
            var word = node[].state.load[ordering=Ordering.RELAXED]()
            if word & _STATE_MASK != _PENDING:
                self._remove_at(0)
                self._retire(slot)
                continue
            if self._keys.unsafe_get(0) > now:
                return None
            if node[].state.compare_exchange[success_ordering=Ordering.RELAXED, failure_ordering=Ordering.RELAXED](word, _word(word >> 3, _CLAIMED)):
                var item = self._payloads.ptr(slot).unsafe_take_pointee()
                self._remove_at(0)
                self._recycle(slot, word)
                return Optional(item^)
            # Canceled or stolen meanwhile: the next iteration retires it.
        return None

    def next_deadline(mut self) -> Optional[UInt64]:
        """Owner only: the earliest live deadline, discarding finished entries at the root."""
        while self._length > 0:
            var slot = Int(self._order.unsafe_get(0))
            if self._nodes.ptr(slot)[].state.load[ordering=Ordering.RELAXED]() & _STATE_MASK == _PENDING:
                return self._keys.unsafe_get(0)
            self._remove_at(0)
            self._retire(slot)
        return None

    def cancel_owned(mut self, ticket: _Ticket) -> Optional[Self.T]:
        """Owner only: cancel and remove immediately, returning the payload if still pending."""
        var node = self._nodes.ptr(ticket.index)
        var word = _word(ticket.generation, _PENDING)
        if not node[].state.compare_exchange[success_ordering=Ordering.RELAXED, failure_ordering=Ordering.RELAXED](word, _word(ticket.generation, _CLAIMED)):
            return None
        var item = self._payloads.ptr(ticket.index).unsafe_take_pointee()
        # A PENDING node is always in the heap: entries leave only once claimed.
        self._remove_at(self._positions.unsafe_get(ticket.index))
        self._recycle(ticket.index, word)
        return Optional(item^)

    def pack_if_needed(mut self):
        """Owner only: drop finished entries once counted cancellations reach half the heap."""
        self._drain()
        var canceled = self._shared[].canceled.load[ordering=Ordering.RELAXED]() - self._accounted
        if canceled == 0 or canceled * 2 < UInt64(self._length):
            return
        var kept = 0
        for read in range(self._length):
            var slot = self._order.unsafe_get(read)
            if self._nodes.ptr(Int(slot))[].state.load[ordering=Ordering.RELAXED]() & _STATE_MASK == _PENDING:
                self._place(kept, slot, self._keys.unsafe_get(read))
                kept += 1
            else:
                self._positions.unsafe_get(Int(slot)) = -1
                self._retire(Int(slot))
        self._length = kept
        if kept == 0:
            self._shared[].earliest.store[ordering=Ordering.RELAXED](UInt64.MAX)
        self._order.resize(kept, 0)
        self._keys.resize(kept, 0)
        var position = kept // 2
        while position > 0:
            position -= 1
            self._sift_down(position, self._order.unsafe_get(position), self._keys.unsafe_get(position))
        self._shared[].size.store[ordering=Ordering.RELEASE](kept)

    def len(self) -> Int:
        """Owner only: heap entries, including finished ones not yet removed."""
        return self._length

    # Operations from any thread.

    def cancel(self, ticket: _Ticket) -> Optional[Self.T]:
        """Any thread: claim a pending timer and return its payload; None if already gone.

        The ticket must have been passed to this thread with synchronization.
        The owner removes the node later (see `pack_if_needed`).
        """
        var node = self._nodes.ptr(ticket.index)
        var word = _word(ticket.generation, _PENDING)
        if not node[].state.compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](word, _word(ticket.generation, _CLAIMED)):
            return None
        var item = self._payloads.ptr(ticket.index).unsafe_take_pointee()
        _ = self._shared[].canceled.fetch_add[ordering=Ordering.RELAXED](1)
        node[].state.store[ordering=Ordering.RELEASE](_word(ticket.generation, _CANCELED))
        return Optional(item^)

    def steal_into(self, now: UInt64, mut out: List[Self.T], limit: Int) -> Int:
        """Another worker: take up to `limit` payloads due at `now`, appending them to `out`.

        Walks the heap from the root and descends only below expired nodes, as
        upstream. Returns the number taken. The owner removes the entries later.
        """
        if limit <= 0 or self._shared[].earliest.load[ordering=Ordering.RELAXED]() > now:
            return 0
        var size = self._shared[].size.load[ordering=Ordering.ACQUIRE]()
        if size == 0:
            return 0
        comptime depth = 64
        var stack = Array[Int, depth](fill=0)
        var top = 1
        var taken = 0
        while top > 0 and taken < limit:
            top -= 1
            var position = stack[top]
            if position >= size:
                continue
            var slot = Int(self._entries.ptr(position)[].load[ordering=Ordering.ACQUIRE]())
            var node = self._nodes.ptr(slot)
            var word = node[].state.load[ordering=Ordering.ACQUIRE]()
            if node[].deadline.load[ordering=Ordering.ACQUIRE]() > now:
                continue
            if word & _STATE_MASK == _PENDING:
                if node[].state.compare_exchange[success_ordering=Ordering.ACQUIRE, failure_ordering=Ordering.RELAXED](word, _word(word >> 3, _CLAIMED)):
                    out.append(self._payloads.ptr(slot).unsafe_take_pointee())
                    node[].state.store[ordering=Ordering.RELEASE](_word(word >> 3, _FIRED))
                    taken += 1
            if top + 2 <= depth:
                stack[top] = 2 * position + 2
                stack[top + 1] = 2 * position + 1
                top += 2
        return taken

    def is_empty_hint(self) -> Bool:
        """Any thread: whether the published heap length is zero."""
        return self._shared[].size.load[ordering=Ordering.RELAXED]() == 0

    # Owner internals.

    def _allocate(mut self) -> Int:
        if not self._free:
            self._drain()
        if self._free:
            return self._free.pop()
        if self._slots == self._nodes.capacity():
            var end = self._nodes.grow()
            _ = self._payloads.grow()
            for i in range(self._slots, end):
                self._nodes.ptr(i).unsafe_write(_TimerNode())
            self._positions.resize(end, -1)
        var slot = self._slots
        self._slots += 1
        return slot

    def _recycle(mut self, slot: Int, word: UInt64):
        var generation = _next_generation(word >> 3)
        if generation >= _GENERATION_LIMIT:
            abort("timer generation exhausted")
        self._nodes.ptr(slot)[].state.store[ordering=Ordering.RELAXED](_word(generation, _FREE))
        self._free.append(slot)

    def _retire(mut self, slot: Int):
        """Recycle a slot whose entry has left the heap, or defer it while a claim is in progress."""
        var word = self._nodes.ptr(slot)[].state.load[ordering=Ordering.ACQUIRE]()
        var state = word & _STATE_MASK
        if state == _CLAIMED:
            self._draining.append(slot)
            return
        if state == _CANCELED:
            self._accounted += 1
        self._recycle(slot, word)

    def _drain(mut self):
        var kept = 0
        for i in range(len(self._draining)):
            var slot = self._draining[i]
            var word = self._nodes.ptr(slot)[].state.load[ordering=Ordering.ACQUIRE]()
            var state = word & _STATE_MASK
            if state == _CLAIMED:
                self._draining[kept] = slot
                kept += 1
                continue
            if state == _CANCELED:
                self._accounted += 1
            self._recycle(slot, word)
        self._draining.resize(kept, 0)

    # Positions below `_length` and slots below `_slots` index these arrays; the
    # owner's invariants replace bounds checks, which were 40% of sifting.

    @always_inline
    def _place(mut self, position: Int, slot: UInt32, key: UInt64):
        """Put `slot` at `position` in the owner's arrays and publish it to thieves."""
        self._order.unsafe_get(position) = slot
        self._keys.unsafe_get(position) = key
        self._positions.unsafe_get(Int(slot)) = position
        self._entries.ptr(position)[].store[ordering=Ordering.RELEASE](slot)
        if position == 0:
            self._shared[].earliest.store[ordering=Ordering.RELAXED](key)

    def _remove_at(mut self, position: Int):
        self._positions.unsafe_get(Int(self._order.unsafe_get(position))) = -1
        self._length -= 1
        var last = self._order.pop()
        var key = self._keys.pop()
        if position != self._length:
            if position > 0 and key < self._keys.unsafe_get((position - 1) // 2):
                self._sift_up(position, last, key)
            else:
                self._sift_down(position, last, key)
        if self._length == 0:
            self._shared[].earliest.store[ordering=Ordering.RELAXED](UInt64.MAX)
        self._shared[].size.store[ordering=Ordering.RELEASE](self._length)

    def _sift_up(mut self, var position: Int, slot: UInt32, key: UInt64):
        """Place `slot` with `key` at the hole `position` or above it."""
        while position > 0:
            var parent = (position - 1) // 2
            if self._keys.unsafe_get(parent) <= key:
                break
            self._place(position, self._order.unsafe_get(parent), self._keys.unsafe_get(parent))
            position = parent
        self._place(position, slot, key)

    def _sift_down(mut self, var position: Int, slot: UInt32, key: UInt64):
        """Place `slot` with `key` at the hole `position` or below it."""
        while True:
            var child = 2 * position + 1
            if child >= self._length:
                break
            if child + 1 < self._length and self._keys.unsafe_get(child + 1) < self._keys.unsafe_get(child):
                child += 1
            if self._keys.unsafe_get(child) >= key:
                break
            self._place(position, self._order.unsafe_get(child), self._keys.unsafe_get(child))
            position = child
        self._place(position, slot, key)
