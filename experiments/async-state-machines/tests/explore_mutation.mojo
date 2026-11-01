"""Exploration finds a planted ordering bug that the deterministic FIFO order hides.

Four fibers each yield once, then hand a counter on: fiber k expects to find
k, left by fiber k - 1, and stores k + 1. That assumes the ready fibers run
in start order, which the contract leaves unspecified. Under today's FIFO
order the assumption always holds; seeded exploration finds a seed that
breaks it, and replaying that seed's trace reproduces the same run.
"""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import Unary
from fp.effects import Outcome
from fp.algebra import par_traverse
from fp.effects.async_runtime import IO, TestControl, ScheduleTrace
from state_machine.exploration import Exploration, expect


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


@fieldwise_init
struct HandOn(Unary, Copyable):
    """Find the expected counter, count a mismatch, and store the next value."""
    var index: Int
    var counter: ArcPointer[Int]
    var broken: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = Int
    comptime Error = Never

    def call(self, var unit: NoneType) -> Int:
        if self.counter[] != self.index:
            self.broken[] += 1
        self.counter[] = self.index + 1
        return self.index


@fieldwise_init
struct Element(Unary, Copyable):
    var counter: ArcPointer[Int]
    var broken: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[Int, Int]:
        return IO[NoneType, Int].cede().map(HandOn(index, self.counter.copy(), self.broken.copy()))


def indices(n: Int) -> List[Int]:
    var values = List[Int]()
    for index in range(n):
        values.append(index)
    return values^


def program(broken: ArcPointer[Int]) -> IO[List[Int], Int]:
    return par_traverse(indices(4), Element(ArcPointer(0), broken.copy()))


def explored(exploration: Exploration, run: Int) -> Tuple[Bool, ScheduleTrace]:
    """Run once; whether the planted assumption broke, and the run's trace."""
    var broken = ArcPointer(0)
    var trace = ScheduleTrace(0)
    var outcome = exploration.complete(program(broken), run, trace)
    expect(trace, Bool(outcome) and outcome.value().is_ok(), "the traversal succeeds")
    return (broken[] > 0, trace^)


def rejected(text: String) -> Bool:
    try:
        _ = ScheduleTrace.parse(text)
        return False
    except:
        return True


def printed_form() raises:
    var empty = ScheduleTrace.parse("seed=18446744073709551615 choices=")
    check(empty.seed() == UInt64.MAX and len(empty.choices()) == 0, "a trace without choices parses")
    var two = ScheduleTrace.parse("seed=7 choices=2/3,0/2")
    check(String(two) == "seed=7 choices=2/3,0/2" and two.choices() == [2, 0], "a trace prints as it parses")
    check(rejected("seed=7 choices=3/3"), "a choice must be below its count")
    check(rejected("seed=7 choices=0/1"), "a recorded choice has at least two candidates")
    check(rejected("seed=18446744073709551616 choices="), "a seed fits 64 bits")
    check(rejected("seed=7"), "the choices are required")
    check(rejected("seed=7 choices=1/2,"), "a trailing comma is rejected")


def main() raises:
    printed_form()
    var exploration = Exploration.from_arguments()
    if exploration.replay:
        var replayed = explored(exploration, 0)
        print("explore mutation: replay", "breaks" if replayed[0] else "keeps", "the planted assumption")
        return

    var broken = ArcPointer(0)
    var fifo = TestControl(program(broken))
    fifo.tick_all()
    check(fifo.is_completed(), "the traversal completes")
    check(not fifo.trace(), "a deterministic control records no trace")
    _ = fifo^.results()
    check(broken[] == 0, "the FIFO order hides the planted bug")

    var found = Optional[ScheduleTrace]()
    for run in range(exploration.runs()):
        var result = explored(exploration, run)
        if result[0] and not found:
            found = Optional(result[1].copy())
    check(Bool(found), "some explored seed finds the planted bug")

    var trace = found.value().copy()
    check(ScheduleTrace.parse(String(trace)) == trace, "the printed trace parses back")
    var replay = Exploration(0, 0)
    replay.replay = Optional(trace.copy())
    var again = explored(replay, 0)
    check(again[0], "replaying the finding trace reproduces the bug")
    check(again[1] == trace, "the replay makes the same choices")
    var by_seed = explored(Exploration(Int(trace.seed()), Int(trace.seed()) + 1), 0)
    check(by_seed[0] and by_seed[1] == trace, "the seed alone reproduces the run")
    print("explore mutation: FIFO hides the planted bug; exploration finds it; the trace and the seed replay it")
