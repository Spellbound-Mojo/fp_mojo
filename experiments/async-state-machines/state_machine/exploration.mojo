"""Seed ranges and replay for the exploration clients (`explore_*`).

A client reads `--seeds A:B` (the half-open range, `0:1000` by default) or
`--replay "<trace>"` from its arguments, runs each scenario under
`TestControl(program, seed=s)` for every seed, or once under
`TestControl(program, replay=trace)`, and on a failed check prints the
run's trace before aborting, so the failure replays exactly.
"""
from std.memory import ArcPointer
from std.os import abort
from std.sys import argv
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects._async.kernel import Machine
from fp.effects.async_runtime import IO, TestControl, ScheduleTrace


struct Exploration(Copyable):
    """The seeds a client explores, or the one trace it replays."""
    var first: Int
    var last: Int
    var replay: Optional[ScheduleTrace]

    def __init__(out self, first: Int, last: Int):
        self.first = first
        self.last = last
        self.replay = None

    @staticmethod
    def from_arguments() -> Self:
        """Read `--seeds A:B` or `--replay TRACE`; `0:1000` without either."""
        var exploration = Self(0, 1000)
        var arguments = argv()
        var at = 1
        while at < len(arguments):
            var name = String(arguments[at])
            if at + 1 >= len(arguments):
                abort(String("missing value for ", name))
            var value = String(arguments[at + 1])
            try:
                if name == "--seeds":
                    var parts = value.split(":")
                    if len(parts) != 2:
                        abort("--seeds takes A:B")
                    exploration.first = atol(parts[0])
                    exploration.last = atol(parts[1])
                    if exploration.first < 0 or exploration.last < exploration.first:
                        abort("--seeds takes 0 <= A <= B")
                elif name == "--replay":
                    exploration.replay = Optional(ScheduleTrace.parse(value))
                else:
                    abort(String("unknown argument ", name))
            except error:
                abort(String("invalid ", name, ": ", error))
            at += 2
        return exploration^

    def runs(self) -> Int:
        """How many runs each scenario takes: the range's length, or one replay."""
        if self.replay:
            return 1
        return self.last - self.first

    def control[P: Machine](self, var program: P, run: Int) -> TestControl[P]:
        """The control for the `run`th run: seed `first + run`, or the replayed trace."""
        if self.replay:
            return TestControl(program^, replay=self.replay.value())
        return TestControl(program^, seed=UInt64(self.first + run))


    def complete[P: Machine](self, var program: P, run: Int, mut trace: ScheduleTrace) -> Outcome[P.Value, P.Error]:
        """Tick the `run`th run to completion on virtual time; its outcome, and its trace in `trace`."""
        var control = self.control(program^, run)
        control.tick_all()
        trace = traced(control)
        expect(trace, control.is_completed(), "the program and its cleanup complete")
        return control^.results()


def traced[P: Machine](control: TestControl[P]) -> ScheduleTrace:
    """The trace of an exploring control, taken before its results are."""
    var trace = control.trace()
    if not trace:
        abort("an exploration client uses an exploring TestControl")
    return trace.value().copy()


def expect(trace: ScheduleTrace, condition: Bool, message: String):
    """Abort with the message and the run's trace when the condition fails."""
    if not condition:
        abort(String(message, "\n  replay with: --replay \"", trace, "\""))


def value_of(var outcome: Outcome[Int, Int]) -> Int:
    """A success's value, -1000 minus a failure's first error, -2 for cancellation."""
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    return -1000 - result^._take_err().errors.first()


@fieldwise_init
struct Then(OnceUnary):
    """Continue with a prepared IO."""
    var next: IO[NoneType, Int]
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        return self.next^


@fieldwise_init
struct Const(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


@fieldwise_init
struct Mark(OnceUnary):
    """Count a step, such as a finalizer's run."""
    var marks: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = NoneType

    def call_once(deinit self, var unit: NoneType) -> NoneType:
        self.marks[] += 1
        return None


def cedes(count: Int) -> IO[NoneType, Int]:
    """Yield `count` times."""
    if count == 0:
        return IO[NoneType, Int].pure(None)
    return IO[NoneType, Int].cede().flat_map(Then(cedes(count - 1)))


def after(count: Int, value: Int) -> IO[Int, Int]:
    """Yield `count` times, then succeed with `value`."""
    return cedes(count).map(Const(value))


def mark(marks: ArcPointer[Int]) -> IO[NoneType, Int]:
    return IO[NoneType, Int].pure(None).map(Mark(marks.copy()))
