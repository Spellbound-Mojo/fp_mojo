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

Memory ordering of each atomic operation:

- `try_claim` succeeds with RELAXED. The slot has never held a value, so the
  winner has no earlier access to order after; it only needs atomicity to be
  the single writer. Failure is RELAXED: the reload is followed by another
  compare-exchange or by giving up, which orders nothing.
- `publish` writes the value and then sets `FULL` with ACQUIRE_RELEASE
  (`put` sets `CLAIMED` and `FULL` in the same step, with the same orderings).
  RELEASE publishes the value to the party whose ACQUIRE step later wins it
  (`take` or `release`). ACQUIRE matters when the receiver released first and
  the writer keeps the value: the releaser's RELEASE step then happens before
  the writer moves the value out, so the receiver's last uses of the slot
  precede it. Failure is RELAXED (the loop retries).
- `take` succeeds with ACQUIRE, pairing with `publish`'s RELEASE, so the value
  and every write made before `publish` are visible to the taker. It needs no
  RELEASE: nobody acquires the value after it. Failure is RELAXED.
- `release` succeeds with ACQUIRE_RELEASE: ACQUIRE when it wins the published
  value (as `take`), RELEASE when it does not, so that a writer that later
  keeps its value (above) observes the receiver's last uses. Failure is
  RELAXED.
- `close` is RELAXED. It only makes later claims fail, and writers whose claim
  fails touch no shared data; whoever later wins the value orders itself with
  its own ACQUIRE step.
- `state` and `published` load with ACQUIRE, so a reader that sees `FULL` also
  sees the writes made before `publish`, as a fiber's joiner sees the child's.
- The destructor reads the state RELAXED: it runs only after the last shared
  owner dropped the slot, and `ArcPointer`'s release decrements and acquire
  fence already order every party's accesses before it.

Cost (`probes/race_primitives_cost.mojo`, O3, four cores): an offer and a
take cost about as much as the same protocol under the spin lock of
`_lock_cell` (82 against 85 ns uncontended). With every thread offering to one
slot, the lock was 20-30% cheaper, since the cost is the cache line's transfer.
The slot is not cheaper; it never sleeps and never runs user code under a lock.

Destroying the slot while a claimed value is unpublished is impossible: the
writer still holds the slot. `wait_published` covers the one caller that must
see a claimed writer finish (a registration that failed while a foreign
completion was being written); it spins briefly, then yields.
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
    """The state word and the value slot in one allocation; fields are initialized one by one."""
    var state: Atomic[UInt8]
    var value: Self.T


struct _OneShot[T: Movable & Deinitable](Movable):
    """One move-only value, written once, owned by exactly one party; see the module docstring.

    The state word and the slot share one allocation, so a decision and the
    value it moves touch one cache line for small values. The cell is never
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
        """Win the single right to write; false once claimed or closed."""
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        while True:
            if state & (_CLAIMED | _CLOSED):
                return False
            if self._cell[].state.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.RELAXED](state, state | _CLAIMED):
                return True

    def publish(self, var value: Self.T) -> Optional[Self.T]:
        """Write and publish the claimed value; returns it when the receiver released first.

        Only the winner of `try_claim` calls this, once.
        """
        self._value_ptr().unsafe_write(value^)
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        while True:
            var keep = Bool(state & _RELEASED)
            var next = state | _FULL | (_TAKEN if keep else UInt8(0))
            if self._cell[].state.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.ACQUIRE_RELEASE](state, next):
                if keep:
                    return Optional(self._value_ptr().unsafe_take_pointee())
                return None

    def put(self, var value: Self.T) -> Optional[Self.T]:
        """Write and publish as the slot's sole writer, in one step; returns the value if nobody can take it.

        For a slot with exactly one writer, such as a fiber's task, which then
        never calls `try_claim`. The value is written first, since no other
        writer can exist, and one compare-exchange sets `CLAIMED` and `FULL`
        together, with `publish`'s orderings. The value comes back when the
        slot was closed or the receiver released first.
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

        Parameters:
            release: Also give up the receiver's right in the same step.
        """
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        while True:
            if not state & _FULL or state & (_TAKEN | _RELEASED):
                return None
            var next = state | _TAKEN | (_RELEASED if release else UInt8(0))
            if self._cell[].state.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.ACQUIRE](state, next):
                return Optional(self._value_ptr().unsafe_take_pointee())

    def release(self) -> Optional[Self.T]:
        """The receiver gives up its right; returns the value when it was published and untaken.

        Releasing twice, or after `take[release=True]`, returns none.
        """
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        while True:
            if state & _RELEASED:
                return None
            var wins = Bool(state & _FULL) and not state & _TAKEN
            var next = state | _RELEASED | (_TAKEN if wins else UInt8(0))
            if self._cell[].state.compare_exchange[failure_ordering=Ordering.RELAXED, success_ordering=Ordering.ACQUIRE_RELEASE](state, next):
                if wins:
                    return Optional(self._value_ptr().unsafe_take_pointee())
                return None

    def close(self) -> UInt8:
        """Make later claims fail; returns the state before closing."""
        var state = self._cell[].state.load[ordering=Ordering.RELAXED]()
        while True:
            if state & _CLOSED:
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
