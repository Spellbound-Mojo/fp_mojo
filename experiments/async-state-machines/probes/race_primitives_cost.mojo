"""Diagnostic timings: the one-shot slot and the closable stack against locked versions (build at -O3; not qualified).

Pass 13 decision 10. Each lock-free primitive is compared with the same
protocol over a `_Cell` guarded by `_lock_cell` (S4's borrowed guard: 256 spins,
then `sleep(0.0)`), and the one-shot also with a guard that sleeps 1 ms when the
lock is held, as `_lock` did for `Completion.complete`. Runs are uncontended
(one thread), contended (2 and 4 threads on this 4-core machine), and
oversubscribed (8 and 16 threads), where a preempted lock holder stalls the
others.

- One-shot: a fresh slot per round. Thread 0 is the receiver and spins until it
  takes the round's value; every other thread offers a value to each round, and
  exactly one offer wins. Reported per round (one decision and one take).
- Stack: every thread pushes its share into one stack, then the main thread
  closes it. Reported per push. The uncontended line pushes 64 elements and
  closes, per element.

Slot and stack allocation is outside the timed region. Wall times on a shared
host vary; compare only runs taken back to back.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.time import perf_counter_ns, sleep
from std.os import abort
from fp._internal.cells import _Cell, _lock_cell, _try_acquire_lock, _release_lock
from fp._internal.oneshot import _OneShot
from fp._internal.closable_stack import _ClosableStack
from fp.effects import unsafe_start, Fiber, IO, IOContext, Outcome, ReaderAction

comptime ROUNDS = 100_000
comptime PUSHES = 400_000

comptime LOCK_FREE = 0
comptime SPIN_LOCK = 1
comptime SLEEP_LOCK = 2


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


@fieldwise_init
struct _ShotState(Movable):
    var closed: Bool
    var value: Optional[Int]


struct LockedShot(Movable):
    """The one-shot protocol under a cell lock: closed on the first offer."""
    var cell: ArcPointer[_Cell[_ShotState]]

    def __init__(out self):
        self.cell = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(_ShotState(False, None))))

    def lock_sleeping(self):
        while not _try_acquire_lock[Ordering.ACQUIRE, Ordering.RELAXED](self.cell[].lock):
            sleep(0.001)

    def put[sleeping: Bool](self, value: Int) -> Bool:
        comptime if sleeping:
            self.lock_sleeping()
            ref state = self.cell[].slot.value()
            var accepted = not state.closed
            if accepted:
                state.closed = True
                state.value = Optional(value)
            _release_lock[Ordering.RELEASE](self.cell[].lock)
            return accepted
        else:
            var guard = _lock_cell(self.cell[])
            ref state = guard.value()
            var accepted = not state.closed
            if accepted:
                state.closed = True
                state.value = Optional(value)
            # The guard is destroyed after its last use: keep it past the section.
            _ = guard^
            return accepted

    def take[sleeping: Bool](self) -> Optional[Int]:
        comptime if sleeping:
            self.lock_sleeping()
            var taken = self.cell[].slot.value().value.take() if self.cell[].slot.value().value else Optional[Int](None)
            _release_lock[Ordering.RELEASE](self.cell[].lock)
            return taken
        else:
            var guard = _lock_cell(self.cell[])
            ref state = guard.value()
            var taken = Optional[Int](None)
            if state.value:
                taken = Optional(state.value.take())
            _ = guard^
            return taken^


struct Rig(Movable):
    var shots: List[_OneShot[Int]]
    var locked: List[LockedShot]
    var stack: _ClosableStack[Int]
    var list: ArcPointer[_Cell[List[Int]]]
    var ready: Atomic[Int]
    var go: Atomic[Int]

    def __init__(out self, rounds: Int, mode: Int):
        self.shots = List[_OneShot[Int]]()
        self.locked = List[LockedShot]()
        for _ in range(rounds):
            if mode == LOCK_FREE:
                self.shots.append(_OneShot[Int]())
            else:
                self.locked.append(LockedShot())
        self.stack = _ClosableStack[Int]()
        self.list = ArcPointer(_Cell(Atomic(UInt8(0)), Optional(List[Int]())))
        self.ready = Atomic(0)
        self.go = Atomic(0)


def shot_role(rig: Rig, mode: Int, receiver: Bool, rounds: Int, me: Int) -> Tuple[Int, Int]:
    """For the receiver: the longest round and the rounds over 100 us, in ns."""
    var longest = 0
    var slow = 0
    for r in range(rounds):
        if receiver:
            var began = Int(perf_counter_ns())
            while True:
                var taken: Optional[Int]
                if mode == LOCK_FREE:
                    taken = rig.shots[r].take()
                elif mode == SPIN_LOCK:
                    taken = rig.locked[r].take[False]()
                else:
                    taken = rig.locked[r].take[True]()
                if taken:
                    break
            var waited = Int(perf_counter_ns()) - began
            longest = max(longest, waited)
            if waited > 100_000:
                slow += 1
        else:
            if mode == LOCK_FREE:
                _ = rig.shots[r].put(me)
            elif mode == SPIN_LOCK:
                _ = rig.locked[r].put[False](me)
            else:
                _ = rig.locked[r].put[True](me)
    return (longest, slow)


def stack_role(rig: Rig, mode: Int, pushes: Int, me: Int):
    for i in range(pushes):
        if mode == LOCK_FREE:
            _ = rig.stack.push(me + i)
        else:
            var guard = _lock_cell(rig.list[])
            guard.value().append(me + i)
            _ = guard^


@fieldwise_init
struct Worker(ReaderAction):
    var rig: ArcPointer[Rig]
    var kind: Int
    var mode: Int
    var receiver: Bool
    var count: Int
    var me: Int
    comptime Family = IO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        _ = self.rig[].ready.fetch_add(1)
        while self.rig[].go.load[ordering=Ordering.ACQUIRE]() == 0:
            pass
        if self.kind == 0:
            _ = shot_role(self.rig[], self.mode, self.receiver, self.count, self.me)
        else:
            stack_role(self.rig[], self.mode, self.count, self.me)
        return Outcome[NoneType, Error](None)


def timed(kind: Int, mode: Int, threads: Int) raises -> Tuple[Int, Int, Int]:
    """Nanoseconds for one run with `threads` threads, the main thread among them,
    with the receiver's longest round and its rounds over 100 us."""
    var tail = (0, 0)
    var count = ROUNDS if kind == 0 else PUSHES // threads
    var rig = ArcPointer(Rig(ROUNDS if kind == 0 else 0, mode))
    var workers = List[Fiber[Worker]]()
    # The main thread is the receiver; threads - 1 helpers offer or push.
    for i in range(threads - 1):
        workers.append(unsafe_start(Worker(rig.copy(), kind, mode, False, count, (i + 1) * 1_000_000)))
    while rig[].ready.load() < threads - 1:
        sleep(0.0001)
    var start = perf_counter_ns()
    rig[].go.store[ordering=Ordering.RELEASE](1)
    if kind == 0:
        if threads == 1:
            # Uncontended: offer, then take, each round.
            for r in range(ROUNDS):
                if mode == LOCK_FREE:
                    _ = rig[].shots[r].put(r)
                    check(Bool(rig[].shots[r].take()), "uncontended take")
                elif mode == SPIN_LOCK:
                    _ = rig[].locked[r].put[False](r)
                    check(Bool(rig[].locked[r].take[False]()), "uncontended take")
                else:
                    _ = rig[].locked[r].put[True](r)
                    check(Bool(rig[].locked[r].take[True]()), "uncontended take")
        else:
            tail = shot_role(rig[], mode, True, ROUNDS, 0)
    else:
        stack_role(rig[], mode, count, 0)
    while workers:
        _ = workers.pop().join()
    if kind == 1:
        var total: Int
        if mode == LOCK_FREE:
            total = len(rig[].stack.close())
        else:
            var guard = _lock_cell(rig[].list[])
            total = len(guard.value())
            _ = guard^
        check(total == count * threads, "every push is received")
    return (Int(perf_counter_ns() - start), tail[0], tail[1])


def stack_uncontended(mode: Int) -> Float64:
    comptime batches = 20_000
    var start = perf_counter_ns()
    var total = 0
    for b in range(batches):
        if mode == LOCK_FREE:
            var stack = _ClosableStack[Int]()
            for i in range(64):
                _ = stack.push(b + i)
            total += len(stack.close())
        else:
            var cell = _Cell(Atomic(UInt8(0)), Optional(List[Int]()))
            for i in range(64):
                var guard = _lock_cell(cell)
                guard.value().append(b + i)
                _ = guard^
            var guard = _lock_cell(cell)
            var taken = List[Int]()
            swap(taken, guard.value())
            _ = guard^
            total += len(taken)
    check(total == batches * 64, "every element is closed out")
    return Float64(Int(perf_counter_ns() - start)) / Float64(batches * 64)


def median(var samples: List[Int]) -> Int:
    sort(samples)
    return samples[len(samples) // 2]


def main() raises:
    var names: List[String] = ["lock-free", "spin lock", "sleep lock"]
    for threads in [1, 2, 4, 8, 16]:
        for mode in range(3):
            var samples = List[Int]()
            var longest = 0
            var slow = 0
            for _ in range(3):
                var run = timed(0, mode, threads)
                samples.append(run[0])
                longest = max(longest, run[1])
                slow += run[2]
            print("one-shot", names[mode], "threads=" + String(threads), "ns_per_round=" + String(Float64(median(samples^)) / Float64(ROUNDS)),
                  "longest_round_us=" + String(longest // 1000), "rounds_over_100us=" + String(slow))
    for mode in range(2):
        print("stack", names[mode], "threads=1 ns_per_push_and_close=" + String(stack_uncontended(mode)))
    for threads in [2, 4, 8, 16]:
        for mode in range(2):
            var samples = List[Int]()
            for _ in range(3):
                samples.append(timed(1, mode, threads)[0])
            print("stack", names[mode], "threads=" + String(threads), "ns_per_push=" + String(Float64(median(samples^)) / Float64((PUSHES // threads) * threads)))
