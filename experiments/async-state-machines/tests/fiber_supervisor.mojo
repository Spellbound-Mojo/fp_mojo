"""Supervisors: fibers outlive their starter, release cancels or awaits, joins still work."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Fiber, Supervisor, Deferred, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def value_of(var outcome: Outcome[Int, Int]) -> Int:
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    return -1000 - result^._take_err().errors.first()


@fieldwise_init
struct Mark(OnceUnary):
    var marks: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = NoneType

    def call_once(deinit self, var unit: NoneType) -> NoneType:
        self.marks[] += 1
        return None


@fieldwise_init
struct MarkThen(OnceUnary):
    """Record that the child ran, then report it through a cell."""
    var marks: ArcPointer[Int]
    var done: Deferred[Int]
    comptime Arg = Int
    comptime Out = IO[Bool, Int]

    def call_once(deinit self, var ignored: Int) -> IO[Bool, Int]:
        self.marks[] += 1
        return self.done.complete[Int](1)


@fieldwise_init
struct One(OnceUnary):
    comptime Arg = Fiber[Bool, Int]
    comptime Out = Int

    def call_once(deinit self, var fiber: Fiber[Bool, Int]) -> Int:
        return 1


@fieldwise_init
struct Starter(OnceUnary):
    """Supervise the child, drop its handle and finish at once."""
    var supervisor: Supervisor[Int]
    var go: Deferred[Int]
    var done: Deferred[Int]
    var marks: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var child = self.go.get[Int]().flat_map(MarkThen(self.marks^, self.done.copy()))
        return self.supervisor.supervise(child^).map(One())


@fieldwise_init
struct JoinStarter(OnceUnary):
    var go: Deferred[Int]
    var done: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var starter: Fiber[Int, Int]) -> IO[Int, Int]:
        # The starter has finished; the supervised child is still waiting for go.
        return starter^.join_with_never().flat_map(Release(self.go^, self.done^))


@fieldwise_init
struct Release(OnceUnary):
    var go: Deferred[Int]
    var done: Deferred[Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        return self.go.complete[Int](1).flat_map(WaitDone(self.done^, value))


@fieldwise_init
struct WaitDone(OnceUnary):
    var done: Deferred[Int]
    var value: Int
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Bool) -> IO[Int, Int]:
        return self.done.get[Int]().map(Plus(self.value))


@fieldwise_init
struct Plus(OnceUnary):
    var base: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return self.base + value


@fieldwise_init
struct Outlive(OnceUnary):
    var go: Deferred[Int]
    var done: Deferred[Int]
    var marks: ArcPointer[Int]
    comptime Arg = Supervisor[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[Int, Int]:
        var starter = IO[NoneType, Int].pure(None).flat_map(Starter(supervisor.copy(), self.go.copy(), self.done.copy(), self.marks^))
        return starter^.start().flat_map(JoinStarter(self.go^, self.done^))


def outlives_starter() raises:
    var marks = ArcPointer(0)
    var go = Deferred[Int]()
    var done = Deferred[Int]()
    var outcome = run(Supervisor[Int].scoped(Outlive(go.copy(), done.copy(), marks.copy())))
    check(value_of(outcome^) == 2 and marks[] == 1, "a supervised fiber outlives the fiber that started it")


def guarded(cleanups: ArcPointer[Int], entered: Deferred[Int]) -> IO[Int, Int]:
    return entered.complete[Int](1).flat_map(Forever(cleanups.copy()))


@fieldwise_init
struct Forever(OnceUnary):
    var cleanups: ArcPointer[Int]
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Bool) -> IO[Int, Int]:
        return IO[Int, Int].never().guarantee(IO[NoneType, Int].cede().map(Mark(self.cleanups^)))


@fieldwise_init
struct Leave(OnceUnary):
    """Drop the supervised handle once the child has entered, then finish."""
    var entered: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return self.entered.get[Int]().map(Plus(6))


@fieldwise_init
struct CancelOnRelease(OnceUnary):
    var cleanups: ArcPointer[Int]
    comptime Arg = Supervisor[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[Int, Int]:
        var entered = Deferred[Int]()
        return supervisor.supervise(guarded(self.cleanups, entered)).flat_map(Leave(entered.copy()))


def release_cancels() raises:
    var cleanups = ArcPointer(0)
    var outcome = run(Supervisor[Int].scoped(CancelOnRelease(cleanups.copy())))
    check(value_of(outcome^) == 7, "the body's outcome is kept")
    check(cleanups[] == 1, "release cancels the live supervised fiber and waits for its cleanup")


@fieldwise_init
struct Steps(OnceUnary):
    """Yield a number of times, then mark."""
    var left: Int
    var marks: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        if self.left == 0:
            return IO[NoneType, Int].pure(None).map(Mark(self.marks^))
        return IO[NoneType, Int].cede().flat_map(Steps(self.left - 1, self.marks^))


@fieldwise_init
struct Finish(OnceUnary):
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = Int

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> Int:
        return 3


@fieldwise_init
struct SuperviseSteps(OnceUnary):
    var marks: ArcPointer[Int]
    comptime Arg = Supervisor[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[Int, Int]:
        var child = IO[NoneType, Int].pure(None).flat_map(Steps(20, self.marks^))
        return supervisor.supervise(child^).map(Finish())


def release_awaits() raises:
    var marks = ArcPointer(0)
    check(value_of(run(Supervisor[Int].scoped(SuperviseSteps(marks.copy()), await_on_release=True))) == 3, "the body completes")
    check(marks[] == 1, "an awaiting release lets the supervised fiber finish")
    marks[] = 0
    check(value_of(run(Supervisor[Int].scoped(SuperviseSteps(marks.copy())))) == 3, "the body completes")
    check(marks[] == 0, "a canceling release stops the supervised fiber before it finishes")


@fieldwise_init
struct JoinIt(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join_with_never()


@fieldwise_init
struct SuperviseValue(OnceUnary):
    comptime Arg = Supervisor[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[Int, Int]:
        return supervisor.supervise(IO[Int, Int].pure(5)).flat_map(JoinIt())


def joins() raises:
    check(value_of(run(Supervisor[Int].scoped(SuperviseValue()))) == 5, "a supervised fiber joins like any fiber")


def main() raises:
    outlives_starter()
    release_cancels()
    release_awaits()
    joins()
    print("fiber supervisor: outliving starters, canceling and awaiting release, joins")
