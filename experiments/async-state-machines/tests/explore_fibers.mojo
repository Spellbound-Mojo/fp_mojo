"""Seeded exploration of fiber races: ties, start/join/cancel, canceled joiners, and cleanup that suspends.

Every scenario runs under `TestControl(program, seed=s)` for each seed of the
range (`--seeds A:B`, `0:1000` by default), or once with `--replay TRACE`.
Each check states only promised behavior, which must hold in every order of
the fibers ready together:

- a race whose sides finish together reports the left side;
- a canceled fiber runs each finalizer it entered exactly once, and `cancel`
  returns only after that cleanup, even when the cleanup suspends;
- a fiber that completes ran its finalizer; every fiber is drained before
  the program completes.

The yield counts vary with the seed, so cancellation lands at different
points of each fiber.
"""
from std.memory import ArcPointer
from fp.callables import OnceUnary
from std.os import abort
from std.collections import Set
from fp.data import Left
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Fiber, Deferred, Duration, RaceResult, ScheduleTrace
from state_machine.exploration import Exploration, expect, value_of, Then, Const, cedes, after, mark


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def winner(var result: RaceResult[Int, Int]) -> Int:
    """The left side's value, or 100 plus the right side's."""
    if result.isa[Left[Int]]():
        return result^.unwrap[Left[Int]]().into_payload()
    return 100 + result^.unwrap[Right[Int]]().into_payload()


from fp.data import Right


def race_ties(exploration: Exploration, run: Int):
    """Sides that finish together: the left one wins in every order."""
    var steps = run % 3
    var trace = ScheduleTrace(0)
    var tie = value_of(exploration.complete(after(steps, 1).race(after(steps, 2)).map(winner), run, trace))
    expect(trace, tie == 1, String("a tie after ", steps, " yields reports the left side"))
    var only = value_of(exploration.complete(IO[Int, Int].never().race(after(steps, 2)).map(winner), run, trace))
    expect(trace, only == 102, "the only side that finishes wins")


@fieldwise_init
struct JoinCode(OnceUnary):
    """Join a fiber and encode its outcome (see `value_of`)."""
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.fiber^.join().map(value_of)


@fieldwise_init
struct CancelAfter(OnceUnary):
    """Yield, cancel the started fiber, then join it."""
    var wait: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        var stop = cedes(self.wait).flat_map(Then(fiber.cancel()))
        return stop^.flat_map(JoinCode(fiber^))


@fieldwise_init
struct JoinStarted(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(value_of)


def start_join_cancel(exploration: Exploration, run: Int) -> Int:
    """Cancel a started fiber after a few yields: it finishes or is canceled, cleaning up once."""
    var work = run % 3
    var wait = (run // 3) % 3
    var finalized = ArcPointer(0)
    var trace = ScheduleTrace(0)
    var child = after(work, 7).guarantee(mark(finalized))
    var code = value_of(exploration.complete(child^.start().flat_map(CancelAfter(wait)), run, trace))
    expect(trace, code == 7 or code == -2, "the joined fiber succeeded or was canceled")
    expect(trace, finalized[] <= 1, "a finalizer runs at most once")
    expect(trace, code != 7 or finalized[] == 1, "a fiber that completed ran its finalizer")
    return code


def canceled_joiner(exploration: Exploration, run: Int) -> Int:
    """Cancel a fiber while it joins its own child: the child is drained, cleaning up once."""
    var work = run % 3
    var wait = (run // 3) % 3
    var child_finalized = ArcPointer(0)
    var joiner_canceled = ArcPointer(0)
    var trace = ScheduleTrace(0)
    var child = after(work, 5).guarantee(mark(child_finalized))
    var joiner = child^.start().flat_map(JoinStarted()).on_cancel(mark(joiner_canceled))
    var code = value_of(exploration.complete(joiner^.start().flat_map(CancelAfter(wait)), run, trace))
    expect(trace, code == 5 or code == -2, "the joiner returned its child's value or was canceled")
    expect(trace, child_finalized[] <= 1 and joiner_canceled[] <= 1, "each finalizer runs at most once")
    expect(trace, code != 5 or (child_finalized[] == 1 and joiner_canceled[] == 0), "a joiner that completed saw its child finish")
    expect(trace, joiner_canceled[] == 0 or code == -2, "an on_cancel finalizer runs only for a canceled joiner")
    return code + 10 * joiner_canceled[] + 100 * child_finalized[]


@fieldwise_init
struct Forever(OnceUnary):
    """After entering, wait forever under a finalizer that yields and sleeps before it marks."""
    var finalized: ArcPointer[Int]
    var yields: Int
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Bool) -> IO[Int, Int]:
        var cleanup = cedes(self.yields).flat_map(Then(IO[NoneType, Int].sleep(Duration()).flat_map(Then(mark(self.finalized)))))
        return IO[Int, Int].never().guarantee(cleanup^)


@fieldwise_init
struct Checked(OnceUnary):
    """After `cancel` returns, read the finalizer count, then join."""
    var finalized: ArcPointer[Int]
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var seen = self.finalized[]
        return self.fiber^.join().map(value_of).map(Seen(seen))


@fieldwise_init
struct Seen(OnceUnary):
    """Keep the count read after `cancel` beside the joined outcome: count * 10 + code."""
    var seen: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var code: Int) -> Int:
        return self.seen * 10 + code


@fieldwise_init
struct CancelEntered(OnceUnary):
    """Wait until the fiber entered its guarded region, yield, cancel it, then check."""
    var entered: Deferred[Int]
    var wait: Int
    var finalized: ArcPointer[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        var stop = self.entered.get[Int]().flat_map(Ignore(cedes(self.wait))).flat_map(Then(fiber.cancel()))
        return stop^.flat_map(Checked(self.finalized^, fiber^))


@fieldwise_init
struct Ignore(OnceUnary):
    var next: IO[NoneType, Int]
    comptime Arg = Int
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var value: Int) -> IO[NoneType, Int]:
        return self.next^


def suspending_cleanup(exploration: Exploration, run: Int):
    """`cancel` waits for a finalizer that yields and sleeps; a race drains such a loser."""
    var yields = run % 3
    var wait = (run // 3) % 3
    var finalized = ArcPointer(0)
    var entered = Deferred[Int]()
    var trace = ScheduleTrace(0)
    var guarded = entered.complete[Int](1).flat_map(Forever(finalized.copy(), yields))
    var code = value_of(exploration.complete(guarded^.start().flat_map(CancelEntered(entered.copy(), wait, finalized.copy())), run, trace))
    expect(trace, code == 10 - 2, "cancel returned after the suspending cleanup ran once, and the join reports cancellation")
    expect(trace, finalized[] == 1, "the suspending cleanup ran exactly once")

    var loser_finalized = ArcPointer(0)
    var loser_entered = Deferred[Int]()
    var loser = loser_entered.complete[Int](1).flat_map(Forever(loser_finalized.copy(), yields))
    var right = loser_entered.get[Int]().flat_map(Ignore(cedes(wait))).map(Const(3))
    var raced = value_of(exploration.complete(loser^.race(right^).map(winner), run, trace))
    expect(trace, raced == 103, "the side that finishes wins")
    expect(trace, loser_finalized[] == 1, "the race drains its loser's suspending cleanup once")


def main():
    var exploration = Exploration.from_arguments()
    # Distinct outcomes seen, so a full range shows it reached both endings.
    var completed = 0
    var canceled = 0
    var joiners = Set[Int]()
    for run in range(exploration.runs()):
        race_ties(exploration, run)
        if start_join_cancel(exploration, run) == 7:
            completed += 1
        else:
            canceled += 1
        joiners.add(canceled_joiner(exploration, run))
        suspending_cleanup(exploration, run)
    if exploration.runs() >= 100:
        check(completed > 0 and canceled > 0, "the range reaches both a completed and a canceled fiber")
        check(len(joiners) >= 3, "the range reaches a completed joiner, a joiner canceled while it waits, and one canceled before it ran")
    print("explore fibers: ties report the left side; start, join and cancel; canceled joiners; suspending cleanup runs once")
