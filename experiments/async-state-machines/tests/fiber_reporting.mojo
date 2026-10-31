"""Fiber failures: each is joined or reported exactly once, and successes are destroyed once."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.data import Result, Err, NonEmptyList
from fp.effects import Outcome, EffectFailure
from fp._internal.erased import _Erased
from fp.effects._async.fibers import _FiberRecord, _Claim, _Delivery
from fp.effects.async_runtime import IO, Fiber, Deferred, IORuntimeConfig, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def report(line: String):
    print("reported:", line)


def reporting() -> IORuntimeConfig:
    var config = IORuntimeConfig()
    config.reporter = report
    return config^


@fieldwise_init
struct Raise(OnceUnary):
    var code: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var ignored: Int) -> IO[Int, Int]:
        return IO[Int, Int].raise_error(self.code)


@fieldwise_init
struct Signal(OnceUnary):
    var cell: Deferred[Int]
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        return self.cell.complete[Int](1).map(Unit())


@fieldwise_init
struct Unit(OnceUnary):
    comptime Arg = Bool
    comptime Out = NoneType

    def call_once(deinit self, var ignored: Bool) -> NoneType:
        return None


def finishing(go: Deferred[Int], done: Deferred[Int], code: Int) -> IO[Int, Int]:
    """Wait for go, then fail; completing done is the child's last cleanup."""
    return go.get[Int]().flat_map(Raise(code)).guarantee(IO[NoneType, Int].pure(None).flat_map(Signal(done.copy())))


@fieldwise_init
struct DropThenRelease(OnceUnary):
    var go: Deferred[Int]
    var done: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        # The handle is gone before the child fails.
        return IO[NoneType, Int].pure(None).flat_map(Signal(self.go.copy())).flat_map(WaitFor(self.done.copy()))


@fieldwise_init
struct WaitFor(OnceUnary):
    var cell: Deferred[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return self.cell.get[Int]()


@fieldwise_init
struct KeepUntilDone(OnceUnary):
    """Release the child, wait for its last cleanup, then drop the handle."""
    var go: Deferred[Int]
    var done: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        var waiting = IO[NoneType, Int].pure(None).flat_map(Signal(self.go.copy())).flat_map(WaitFor(self.done.copy()))
        return waiting^.flat_map(DropLater(fiber^))


@fieldwise_init
struct DropLater(OnceUnary):
    var fiber: Fiber[Int, Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var ignored: Int) -> IO[Int, Int]:
        return IO[Int, Int].pure(0)


def dropped_after_failure() raises:
    print("dropped after failure")
    var go = Deferred[Int]()
    var done = Deferred[Int]()
    _ = run(finishing(go, done, 1).start().flat_map(KeepUntilDone(go.copy(), done.copy())), reporting())


def dropped_before_failure() raises:
    print("dropped before failure")
    var go = Deferred[Int]()
    var done = Deferred[Int]()
    _ = run(finishing(go, done, 2).start().flat_map(DropThenRelease(go.copy(), done.copy())), reporting())


@fieldwise_init
struct JoinIt(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(Code())


@fieldwise_init
struct Code(OnceUnary):
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        if not outcome:
            return -2
        var result = outcome.take()
        if result.is_ok():
            return result^._take_ok()
        return -result^._take_err().errors.first()


def joined_failure() raises:
    print("joined failure")
    var outcome = run(IO[Int, Int].raise_error(3).start().flat_map(JoinIt()), reporting())
    check(Bool(outcome) and outcome.value().is_ok(), "the owner completes")
    check(outcome.take()._take_ok() == -3, "the joiner takes the failure, so nothing is reported")


@fieldwise_init
struct StartJoiner(OnceUnary):
    """Start a joiner fiber that owns the child's handle, cancel it, then let the child fail."""
    var go: Deferred[Int]
    var done: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var child: Fiber[Int, Int]) -> IO[Int, Int]:
        return child^.join().start().flat_map(CancelJoiner(self.go^, self.done^))


@fieldwise_init
struct CancelJoiner(OnceUnary):
    var go: Deferred[Int]
    var done: Deferred[Int]
    comptime Arg = Fiber[Outcome[Int, Int], Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var joiner: Fiber[Outcome[Int, Int], Int]) -> IO[Int, Int]:
        var canceling = IO[NoneType, Int].cede().flat_map(CancelOuter(joiner^))
        return canceling^.flat_map(Signal(self.go.copy())).flat_map(WaitFor(self.done.copy()))


@fieldwise_init
struct CancelOuter(OnceUnary):
    var joiner: Fiber[Outcome[Int, Int], Int]
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        return self.joiner.cancel()


def canceled_joiner() raises:
    print("canceled joiner")
    var go = Deferred[Int]()
    var done = Deferred[Int]()
    _ = run(finishing(go, done, 4).start().flat_map(StartJoiner(go.copy(), done.copy())), reporting())


def dropped_delivery():
    print("dropped delivery")
    var record = ArcPointer(_FiberRecord[Int](True, report))
    var failure: Outcome[_Erased, Int] = Optional(Result[_Erased, EffectFailure[Int]](Err(EffectFailure[Int](NonEmptyList(5), False))))
    record[].complete(failure^)
    var delivery = _Delivery[Int](_Claim[Int](record.copy()))
    _ = delivery^
    check(record[].done() and not record[].outcome.take() and not record[].outcome.release(), "a dropped delivery reports its failure itself, once")


@fieldwise_init
struct Tracked(Movable):
    var drops: ArcPointer[Int]

    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct MakeTracked(OnceUnary):
    var drops: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Tracked

    def call_once(deinit self, var ignored: Int) -> Tracked:
        return Tracked(self.drops^)


@fieldwise_init
struct KeepTrackedUntilDone(OnceUnary):
    var go: Deferred[Int]
    var done: Deferred[Int]
    comptime Arg = Fiber[Tracked, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Tracked, Int]) -> IO[Int, Int]:
        var waiting = IO[NoneType, Int].pure(None).flat_map(Signal(self.go.copy())).flat_map(WaitFor(self.done.copy()))
        return waiting^.flat_map(DropTrackedLater(fiber^))


@fieldwise_init
struct DropTrackedLater(OnceUnary):
    var fiber: Fiber[Tracked, Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var ignored: Int) -> IO[Int, Int]:
        return IO[Int, Int].pure(0)


def dropped_success() raises:
    print("dropped success")
    var drops = ArcPointer(0)
    var go = Deferred[Int]()
    var done = Deferred[Int]()
    var child = go.get[Int]().map(MakeTracked(drops.copy())).guarantee(IO[NoneType, Int].pure(None).flat_map(Signal(done.copy())))
    _ = run(child^.start().flat_map(KeepTrackedUntilDone(go.copy(), done.copy())), reporting())
    check(drops[] == 1, "an unjoined success is destroyed once")


def disabled() raises:
    print("disabled")
    var config = reporting()
    config.report_unhandled_fiber_errors = False
    var go = Deferred[Int]()
    var done = Deferred[Int]()
    _ = run(finishing(go, done, 6).start().flat_map(KeepUntilDone(go.copy(), done.copy())), config)


@fieldwise_init
struct Plain(Movable):
    var code: Int


@fieldwise_init
struct RaisePlain(OnceUnary):
    comptime Arg = Int
    comptime Out = IO[Int, Plain]

    def call_once(deinit self, var ignored: Int) -> IO[Int, Plain]:
        return IO[Int, Plain].raise_error(Plain(7))


@fieldwise_init
struct SignalPlain(OnceUnary):
    var cell: Deferred[Int]
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Plain]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Plain]:
        return self.cell.complete[Plain](1).map(Unit())


@fieldwise_init
struct WaitForPlain(OnceUnary):
    var cell: Deferred[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Plain]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Plain]:
        return self.cell.get[Plain]()


@fieldwise_init
struct KeepPlainUntilDone(OnceUnary):
    var go: Deferred[Int]
    var done: Deferred[Int]
    comptime Arg = Fiber[Int, Plain]
    comptime Out = IO[Int, Plain]

    def call_once(deinit self, var fiber: Fiber[Int, Plain]) -> IO[Int, Plain]:
        var waiting = IO[NoneType, Plain].pure(None).flat_map(SignalPlain(self.go.copy())).flat_map(WaitForPlain(self.done.copy()))
        return waiting^.flat_map(DropPlainLater(fiber^))


@fieldwise_init
struct DropPlainLater(OnceUnary):
    var fiber: Fiber[Int, Plain]
    comptime Arg = Int
    comptime Out = IO[Int, Plain]

    def call_once(deinit self, var ignored: Int) -> IO[Int, Plain]:
        return IO[Int, Plain].pure(0)


def not_writable() raises:
    print("not writable")
    var go = Deferred[Int]()
    var done = Deferred[Int]()
    var child = go.get[Plain]().flat_map(RaisePlain()).guarantee(IO[NoneType, Plain].pure(None).flat_map(SignalPlain(done.copy())))
    _ = run(child^.start().flat_map(KeepPlainUntilDone(go.copy(), done.copy())), reporting())


def main() raises:
    dropped_after_failure()
    dropped_before_failure()
    joined_failure()
    canceled_joiner()
    dropped_delivery()
    dropped_success()
    disabled()
    not_writable()
    print("fiber reporting: dropped handles, joins, canceled joiners, deliveries, successes")
