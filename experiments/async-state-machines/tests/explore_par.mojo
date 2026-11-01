"""Seeded exploration of concurrent traversal and Supervisor release.

Every scenario runs under `TestControl(program, seed=s)` for each seed of the
range (`--seeds A:B`, `0:1000` by default), or once with `--replay TRACE`.
Each check states only promised behavior, which must hold in every order of
the fibers ready together:

- `par_traverse` keeps source order; the first failure stops the rest, the
  failure lists the observed errors in element order, and every element that
  started runs its finalizer exactly once;
- canceling a traversal drains every element that started;
- releasing a `Supervisor` cancels its live fibers and waits for their
  cleanup, or with `await_on_release` waits for them to finish.

Yield counts and the failing element vary with the seed.
"""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary, Unary
from fp.effects import Outcome
from fp.algebra import par_traverse
from fp.effects.async_runtime import IO, Fiber, Supervisor, ScheduleTrace
from state_machine.exploration import Exploration, expect, value_of, Then, Const, cedes, after, mark


comptime ELEMENTS = 6


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def indices() -> List[Int]:
    var values = List[Int]()
    for index in range(ELEMENTS):
        values.append(index)
    return values^


@fieldwise_init
struct Into(OnceUnary):
    """Continue with a prepared IO producing an Int."""
    var next: IO[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.next^


def counted(steps: Int, value: Int, entered: ArcPointer[Int], finalized: ArcPointer[Int]) -> IO[Int, Int]:
    """Mark entry, yield, then succeed, all under a finalizer that yields before it marks."""
    var body = mark(entered).flat_map(Into(after(steps, value)))
    return body^.guarantee(cedes(1).flat_map(Then(mark(finalized))))


@fieldwise_init
struct Element(Unary, Copyable):
    """Element `failing` fails after yielding; the others yield a seed-chosen number of times and succeed."""
    var run: Int
    var failing: Int
    var entered: ArcPointer[Int]
    var finalized: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[Int, Int]:
        var steps = (self.run + index) % 3
        if index == self.failing:
            return cedes(steps).flat_map(Into(IO[Int, Int].raise_error(index)))
        return counted(steps, index * 10, self.entered, self.finalized)


def traverse_order(exploration: Exploration, run: Int):
    var entered = ArcPointer(0)
    var finalized = ArcPointer(0)
    var trace = ScheduleTrace(0)
    var outcome = exploration.complete(par_traverse(indices(), Element(run, -1, entered.copy(), finalized.copy())), run, trace)
    expect(trace, Bool(outcome) and outcome.value().is_ok(), "a traversal without failures succeeds")
    var values = outcome.take()._take_ok()
    expect(trace, len(values) == ELEMENTS, "one result per element")
    for index in range(ELEMENTS):
        expect(trace, values[index] == index * 10, "results keep source order")
    expect(trace, entered[] == ELEMENTS and finalized[] == ELEMENTS, "every element ran and cleaned up once")


def traverse_failure(exploration: Exploration, run: Int):
    """One element fails: the traversal fails with its error, and every started element cleans up once."""
    var failing = run % ELEMENTS
    var entered = ArcPointer(0)
    var finalized = ArcPointer(0)
    var trace = ScheduleTrace(0)
    var outcome = exploration.complete(par_traverse(indices(), Element(run, failing, entered.copy(), finalized.copy())), run, trace)
    expect(trace, Bool(outcome) and outcome.value().is_err(), "a failing element fails the traversal")
    var failure = outcome.take()._take_err()
    var errors = failure^.into_errors().into_list()
    expect(trace, len(errors) == 1 and errors[0] == failing, "the failure lists the failing element's error")
    expect(trace, entered[] <= finalized[] and finalized[] <= ELEMENTS - 1, "every element that started cleaned up exactly once")


def size(var values: List[Int]) -> Int:
    return len(values)


@fieldwise_init
struct JoinCode(OnceUnary):
    var fiber: Fiber[Int, Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.fiber^.join().map(value_of)


@fieldwise_init
struct CancelAfter(OnceUnary):
    var wait: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        var stop = cedes(self.wait).flat_map(Then(fiber.cancel()))
        return stop^.flat_map(JoinCode(fiber^))


def traverse_cancel(exploration: Exploration, run: Int) -> Int:
    """Cancel a running traversal: it completes or is canceled, and every started element cleans up once."""
    var wait = (run // 3) % 12
    var entered = ArcPointer(0)
    var finalized = ArcPointer(0)
    var trace = ScheduleTrace(0)
    var traversal = par_traverse(indices(), Element(run, -1, entered.copy(), finalized.copy())).map(size)
    var code = value_of(exploration.complete(traversal^.start().flat_map(CancelAfter(wait)), run, trace))
    expect(trace, code == ELEMENTS or code == -2, "the traversal completed or was canceled")
    expect(trace, entered[] <= finalized[] and finalized[] <= ELEMENTS, "canceling drains every started element, which cleans up once")
    expect(trace, code != ELEMENTS or finalized[] == ELEMENTS, "a completed traversal cleaned up every element")
    return code


@fieldwise_init
struct SuperviseFrom(OnceUnary):
    """Supervise children `next` to the last, dropping each handle, then yield and finish with 9."""
    var supervisor: Supervisor[Int]
    var next: Int
    var run: Int
    var entered: ArcPointer[Int]
    var finalized: ArcPointer[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var previous: Fiber[Int, Int]) -> IO[Int, Int]:
        return supervise_from(self.supervisor, self.next, self.run, self.entered, self.finalized)


def supervise_from(supervisor: Supervisor[Int], next: Int, run: Int, entered: ArcPointer[Int], finalized: ArcPointer[Int]) -> IO[Int, Int]:
    if next == 3:
        return after((run // 3) % 3, 9)
    var child = counted((run + next) % 4, next, entered, finalized)
    return supervisor.supervise(child^).flat_map(SuperviseFrom(supervisor.copy(), next + 1, run, entered.copy(), finalized.copy()))


@fieldwise_init
struct Body(OnceUnary):
    var run: Int
    var entered: ArcPointer[Int]
    var finalized: ArcPointer[Int]
    comptime Arg = Supervisor[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[Int, Int]:
        return supervise_from(supervisor, 0, self.run, self.entered, self.finalized)


def supervisor_release(exploration: Exploration, run: Int) -> Int:
    var entered = ArcPointer(0)
    var finalized = ArcPointer(0)
    var trace = ScheduleTrace(0)
    var code = value_of(exploration.complete(Supervisor[Int].scoped(Body(run, entered.copy(), finalized.copy())), run, trace))
    expect(trace, code == 9, "the body's outcome is kept")
    expect(trace, entered[] <= finalized[] and finalized[] <= 3, "release cancels the live fibers and waits for their cleanup, once each")
    var stopped = 3 - finalized[]

    entered[] = 0
    finalized[] = 0
    code = value_of(exploration.complete(Supervisor[Int].scoped(Body(run, entered.copy(), finalized.copy()), await_on_release=True), run, trace))
    expect(trace, code == 9, "the body's outcome is kept")
    expect(trace, entered[] == 3 and finalized[] == 3, "an awaiting release lets every supervised fiber finish")
    return stopped


def main():
    var exploration = Exploration.from_arguments()
    var canceled = 0
    var completed = 0
    var stopped = 0
    for run in range(exploration.runs()):
        traverse_order(exploration, run)
        traverse_failure(exploration, run)
        if traverse_cancel(exploration, run) == -2:
            canceled += 1
        else:
            completed += 1
        stopped += supervisor_release(exploration, run)
    if exploration.runs() >= 100:
        check(canceled > 0 and completed > 0, "the range reaches both a canceled and a completed traversal")
        check(stopped > 0, "the range reaches a release that stops a supervised fiber")
    print("explore par: par_traverse order, failure and cancellation; Supervisor release cancels or awaits")
