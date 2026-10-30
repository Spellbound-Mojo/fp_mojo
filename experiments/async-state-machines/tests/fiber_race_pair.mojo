"""Race pairs: the first outcome and the other fiber, ties, caller cancellation and draining."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.data import Left, Right
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, RaceWinner, RacePairResult, Driver, Clock, IORuntimeConfig, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def summary(var outcome: Outcome[Int, Int]) -> Int:
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    return -1000 - result^._take_err().errors.first()


comptime Pair = RacePairResult[Int, Int, Int]


@fieldwise_init
struct Settle(OnceUnary):
    """Encode the winning side and outcome, then cancel and join the loser."""
    comptime Arg = Pair
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var pair: Pair) -> IO[Int, Int]:
        var side = 100
        var won: RaceWinner[Int, Int, Int]
        if pair.isa[Left[RaceWinner[Int, Int, Int]]]():
            won = pair^.unwrap[Left[RaceWinner[Int, Int, Int]]]().into_payload()
        else:
            side = 200
            won = pair^.unwrap[Right[RaceWinner[Int, Int, Int]]]().into_payload()
        var code = side + summary(won.take_outcome())
        var loser = won^.into_loser()
        var stopping = loser.cancel()
        return stopping^.flat_map(JoinLoser(loser^, code))


@fieldwise_init
struct JoinLoser(OnceUnary):
    """Join the canceled loser; report the winner's code and the loser's outcome."""
    var loser: Fiber[Int, Int]
    var code: Int
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.loser^.join().map(Encode(self.code))


@fieldwise_init
struct Encode(OnceUnary):
    var code: Int
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        return self.code * 10000 + summary(outcome^) + 5000


def raced(var left: IO[Int, Int], var right: IO[Int, Int]) -> Int:
    return summary(run(left^.race_pair(right^).flat_map(Settle())))


@fieldwise_init
struct Mark(OnceUnary):
    var marks: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = NoneType

    def call_once(deinit self, var unit: NoneType) -> NoneType:
        self.marks[] += 1
        return None


def guarded(marks: ArcPointer[Int]) -> IO[Int, Int]:
    return IO[Int, Int].never().guarantee(IO[NoneType, Int].cede().map(Mark(marks.copy())))


def main() raises:
    # left, its outcome 1; the loser was canceled: -2 + 5000.
    check(raced(IO[Int, Int].pure(1), IO[Int, Int].never()) == 101 * 10000 + 4998, "left finishes first")
    check(raced(IO[Int, Int].never(), IO[Int, Int].pure(2)) == 202 * 10000 + 4998, "right finishes first")
    # A tie favors the left side; the right finished too, so its join keeps its success.
    check(raced(IO[Int, Int].pure(3), IO[Int, Int].pure(4)) == 103 * 10000 + 5004, "a tie favors the left side")
    check(raced(IO[Int, Int].raise_error(5), IO[Int, Int].never()) == (100 - 1005) * 10000 + 4998, "a failing winner keeps its errors")

    # A caller canceled while waiting cancels both fibers and drains them first.
    var marks = ArcPointer(0)
    var driver = Driver(guarded(marks).race_pair(guarded(marks)).flat_map(Settle()), CancellationToken(), Clock(), IORuntimeConfig())
    for _ in range(4):
        _ = driver.poll()
    driver.request_cancel()
    var polls = 0
    while not driver.poll().completed:
        polls += 1
        check(polls < 1000, "the canceled race drains")
    check(not driver^.finish(), "the caller is canceled")
    check(marks[] == 2, "both fibers were canceled and cleaned up before completion")
    print("fiber race pair: left, right, ties, failures, caller cancellation")
