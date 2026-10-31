"""A one-shot slot: one move-only value, written once and owned by exactly one party.

After Tokio's `oneshot`. An atomic state word sits over a slot for one value,
in one allocation behind a pointer, so every method takes immutable
`self` and the slot may be shared (inside an `ArcPointer`) by any number of
threads. The parties are:

- **writers**, who compete with `try_claim` for the single right to write, or
  a sole writer, which writes and publishes in one step with `put`;
- the **receiver**, the one party entitled to `take` the value or to `release`
  its right to it (fiber records give this right to the handle's claim);
- **closers**, who stop further claims with `close`.

The value is written by exactly one thread, the claim's winner, and published
with release ordering by `publish`. After that, whoever wins the next atomic
step owns the value exclusively and moves it out of the slot:

- `take` by the receiver, while it has not released;
- `release` by the receiver, when the value is already published (the
  receiver then disposes of a value nobody will take);
- `publish` itself, when the receiver released first (the writer keeps its
  value, as Tokio's `send` returns it to the sender).

Exactly one of them wins, since each decides with one compare-exchange on the
same word. A value nobody moved out is destroyed with the slot, when the last
owner of the slot drops it. The slot never runs a payload destructor while
another party may still use it: winners move the value out first and destroy
it outside the slot, and the slot's own destructor runs only once no party
holds it.

States are bits of one `UInt8`:

- `CLAIMED`: a writer won the right to write; nobody else can claim.
- `FULL`: the value is written and published.
- `CLOSED`: claims fail from now on; a published value stays takeable.
- `TAKEN`: the value has left the slot (taken, or kept by a winning releaser
  or writer).
- `RELEASED`: the receiver gave up its right; `take` fails.

Single-writer windows. The protocol keeps read-modify-writes to the steps
that can actually race, and every other change is a plain atomic store by the
one party that may write the word at that moment:

- Between a successful `try_claim` and `publish`, nobody else writes the
  state: claims fail on `CLAIMED` by reading, `close` writes nothing once the
  slot is claimed (claims already fail), and a `release` that finds a claimed,
  unpublished value waits for its writer (`wait_published`), as the value is
  one move away. So `publish` is a store.
- After `FULL`, only the receiver writes the state, so `take` is a load and a
  store, and so is a `release` of a published value.
- `try_claim`, `put`, `close` of an unclaimed slot, and `release` of an
  unclaimed slot are compare-exchanges: they race with one another.

Fiber records publish with `put`, in one step, so their receiver never waits;
a `Completion`'s receiver never releases. Failing parties fail on a read: a
writer that loses the claim, a taker that finds nothing published, and a
closer of a claimed slot never write the word.

Memory ordering of each atomic operation:

- `try_claim` reads RELAXED and, when the slot is free, compare-exchanges to
  `CLAIMED` with ACQUIRE on success (RELAXED on failure: it only retries or
  gives up). ACQUIRE pairs with a receiver's RELEASE release of the unclaimed
  slot, so a writer that then keeps its value does so after the receiver's
  last uses.
- `publish` writes the value, reads the state RELAXED (it cannot change in the
  window above), and stores `FULL` with RELEASE, publishing the value to the
  receiver's ACQUIRE load. If the receiver had released, it stores `FULL` and
  `TAKEN` and keeps the value.
- `put` writes the value and compare-exchanges `CLAIMED | FULL` with
  ACQUIRE_RELEASE: RELEASE publishes the value, and ACQUIRE orders a keep
  after a receiver's release, as `try_claim` does. Failure is RELAXED.
- `take` and `release` load with ACQUIRE, pairing with the publication, so the
  value and everything written before it are visible. Their stores of `TAKEN`
  or `RELEASED` after publication are RELAXED: no party acquires anything from
  them, and the destructor is ordered by `ArcPointer`'s fences (below). The
  release of an unclaimed slot is a compare-exchange with RELEASE on success
  and ACQUIRE on failure (a reload that may find a published value to win).
- `close` reads RELAXED and compare-exchanges `CLOSED` RELAXED: it only makes
  later claims fail, and writers whose claim fails touch no shared data.
- `state`, `published` and `wait_published` load with ACQUIRE, so a reader that
  sees `FULL` also sees the writes made before publication, as a fiber's
  joiner sees the child's.
- The destructor reads the state RELAXED: it runs only after the last shared
  owner dropped the slot, and `ArcPointer`'s release decrements and acquire
  fence already order every party's accesses before it.

Cost (`probes/race_primitives_cost.mojo`, O3, four cores, medians of five
runs with their min-max spreads, ns per round). An offer and a take cost one
read-modify-write uncontended. In the storm, every thread but one offers to
the same slot, and one receiver spins on it, round after round:

| Threads | One-shot | `_lock_cell` spin lock |
|---|---|---|
| 1 | 37 [37-47] | 62 [57-64] |
| 2 | 77 [76-83] | 96 [96-98] |
| 4 | 110 [94-113] | 110 [106-127] |
| 8 | 173 [167-183] | 155 [100-168] |
| 16 | 198 [187-214] | 176 [122-277] |

Oversubscribed, at 8 and 16 threads on four cores, the slot is about 11%
slower than the spin lock, as the state's line moves between preempted
threads. The spin lock's own median at 8 threads swung from 98 to 155 ns
between runs on the same day. The storm bounds rather than models real use: a
fiber record has a single writer, which publishes in one step with `put`, and
a `Completion` typically sees two or three parties, rarely at once. Reading
before the claim's compare-exchange saved nothing measurable in the storm; the
gain over the first version (88 ns uncontended, 150 at 8 threads) came from
making publication and taking plain stores. Kept lock-free by Pass 13
decision 11.

Destroying the slot while a claimed value is unpublished is impossible: the
writer still holds the slot.
"""
from std.atomic import Atomic, Ordering
from std.memory.alloc import unsafe_alloc
from std.os import abort
from std.time import sleep

comptime _CLAIMED = UInt8(1)
comptime _FULL = UInt8(2)
comptime _CLOSED = UInt8(4)
comptime _TAKEN = UInt8(8)
comptime _RELEASED = UInt8(16)

comptime _WAIT_SPINS = 256
"""Reloads `wait_published` makes before yielding the processor."""


struct _ShotCell[T: Movable & Deinitable]:
    """The state word and the value slot, side by side in one allocation.

    The cell is never constructed or destroyed as a whole: the state is
    written at creation and the value only by its writer, and each is
    destroyed on its own. The two share a line on purpose: the winner of a
    decision moves the value it decided, so a padded layout, with the state
    alone on an aligned 64-byte line, measured slower uncontended (72 against
    38 ns per offer and take) and no faster contended.
    """
    var state: Atomic[UInt8]
    var value: Self.T


struct _OneShot[T: Movable & Deinitable](Movable):
    """One move-only value, written once, owned by exactly one party; see the module docstring.

    The state word and the slot share one allocation, made once per owner
    and never per operation. The cell is never
    constructed or destroyed as a whole: the state is written at creation and
    the value only by `publish`, and each is destroyed on its own.

    Parameters:
        T: The value, moved between threads.
    """
    var _cell: Pointer[_ShotCell[Self.T], MutUntrackedOrigin]

    def __init__(out self):
        self._cell = unsafe_alloc[_ShotCell[Self.T]](1)
        self._state_ptr().unsafe_write(Atomic(UInt8(0)))

    def __deinit__(deinit self):
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        if state & _FULL and not state & _TAKEN:
            self._value_ptr().unsafe_deinit_pointee()
        self._state_ptr().unsafe_deinit_pointee()
        self._cell.unsafe_free()

    @always_inline
    def _state_ptr(self) -> Pointer[Atomic[UInt8], MutUntrackedOrigin]:
        return Pointer[Atomic[UInt8], MutUntrackedOrigin](to=self._cell[].state)

    @always_inline
    def _value_ptr(self) -> Pointer[Self.T, MutUntrackedOrigin]:
        return Pointer[Self.T, MutUntrackedOrigin](to=self._cell[].value)

    @always_inline
    def state(self) -> UInt8:
        """The state bits, loaded with ACQUIRE."""
        return self._cell[].state.load[ordering=Ordering.ACQUIRE]()

    @always_inline
    def published(self) -> Bool:
        """Whether a value was published; writes before `publish` are then visible."""
        return Bool(self.state() & _FULL)

    def try_claim(self) -> Bool:
        """Win the single right to write; false once claimed or closed, after one read."""
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        while True:
            if state & (_CLAIMED | _CLOSED):
                return False
            if self._cell[].state.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.ACQUIRE](state, state | _CLAIMED):
                return True

    def publish(self, var value: Self.T) -> Optional[Self.T]:
        """Write and publish the claimed value; returns it when the receiver released first.

        Only the winner of `try_claim` calls this, once. Nobody else writes the
        state until it does, so publication is a store.
        """
        self._value_ptr().unsafe_write(value^)
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        if state & _RELEASED:
            self._cell[].state.store[ordering=Ordering.RELAXED](state | _FULL | _TAKEN)
            return Optional(self._value_ptr().unsafe_take_pointee())
        self._cell[].state.store[ordering=Ordering.RELEASE](state | _FULL)
        return None

    def put(self, var value: Self.T) -> Optional[Self.T]:
        """Write and publish as the slot's sole writer, in one step; returns the value if nobody can take it.

        For a slot with exactly one writer, such as a fiber's task, which then
        never calls `try_claim`. The value is written first, since no other
        writer can exist, and one compare-exchange sets `CLAIMED` and `FULL`
        together. The value comes back when the slot was closed or the receiver
        released first.
        """
        self._value_ptr().unsafe_write(value^)
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        while True:
            if state & _CLAIMED:
                abort("a sole writer's one-shot slot was claimed twice")
            if state & _CLOSED:
                return Optional(self._value_ptr().unsafe_take_pointee())
            var keep = Bool(state & _RELEASED)
            var next = state | _CLAIMED | _FULL | (_TAKEN if keep else UInt8(0))
            if self._cell[].state.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.ACQUIRE_RELEASE](state, next):
                if keep:
                    return Optional(self._value_ptr().unsafe_take_pointee())
                return None

    def take[release: Bool = False](self) -> Optional[Self.T]:
        """The receiver takes the published value; none before publication or after release.

        Only the receiver writes the state once it is published, so a take is
        a load and a store.

        Parameters:
            release: Also give up the receiver's right in the same step.
        """
        var state = self._cell[].state.load[ordering=Ordering.ACQUIRE]()
        if not state & _FULL or state & (_TAKEN | _RELEASED):
            return None
        self._cell[].state.store[ordering=Ordering.RELAXED](state | _TAKEN | (_RELEASED if release else UInt8(0)))
        return Optional(self._value_ptr().unsafe_take_pointee())

    def release(self) -> Optional[Self.T]:
        """The receiver gives up its right; returns the value when it was published and untaken.

        Releasing twice, or after `take[release=True]`, returns none. A claimed,
        unpublished value is waited for, then won.
        """
        var state = self._cell[].state.load[ordering=Ordering.ACQUIRE]()
        while True:
            if state & _RELEASED:
                return None
            if state & _FULL:
                if state & _TAKEN:
                    self._cell[].state.store[ordering=Ordering.RELAXED](state | _RELEASED)
                    return None
                self._cell[].state.store[ordering=Ordering.RELAXED](state | _RELEASED | _TAKEN)
                return Optional(self._value_ptr().unsafe_take_pointee())
            if state & _CLAIMED:
                self.wait_published()
                state = self._cell[].state.load[ordering=Ordering.ACQUIRE]()
                continue
            if self._cell[].state.compare_exchange[failure_ordering=Ordering.ACQUIRE, success_ordering=Ordering.RELEASE](state, state | _RELEASED):
                return None

    def close(self) -> UInt8:
        """Make later claims fail; returns the state before closing.

        A claimed slot is left unwritten: its claims already fail.
        """
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        while True:
            if state & (_CLOSED | _CLAIMED):
                return state
            if self._cell[].state.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELAXED](state, state | _CLOSED):
                return state

    def wait_published(self):
        """Wait until a claimed value is published; returns at once when nothing is claimed."""
        var spins = 0
        while True:
            var state = self.state()
            if not state & _CLAIMED or state & _FULL:
                return
            spins += 1
            if spins >= _WAIT_SPINS:
                spins = 0
                sleep(0.0)

    def peek(self) -> Pointer[Self.T, MutUntrackedOrigin]:
        """The published, untaken value in place, for the receiver only.

        Valid only while `published()` is true and the caller, the receiver,
        has neither taken nor released: nothing else can move it out then.
        """
        return self._value_ptr()
