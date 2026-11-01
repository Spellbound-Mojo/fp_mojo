"""Fibers preserve typed outcomes and wait for cooperative finalization."""
from std.atomic import Atomic
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from std.time import sleep, monotonic
from std.sys.info import CompilationTarget
from fp.effects import unsafe_start
from fp.effects import IO, IOContext, IOContract, Outcome, ReaderAction, CancellationToken, delay, guarantee, run_io
from fp.callables import OnceThunk


@fieldwise_init
struct FiberTestWait(ReaderAction):
    var ready: ArcPointer[Atomic[UInt8]]
    comptime Family = IO[Int]
    comptime Env = IOContext[Int]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Int]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        self.ready[].store(1)
        var deadline = monotonic() + 10_000_000_000
        while not context.canceled() and monotonic() < deadline:
            sleep(0.001)
        return None


@fieldwise_init
struct FiberTestFinish(OnceThunk):
    var count: ArcPointer[Atomic[Int]]
    var fail: Bool
    comptime Out = NoneType
    comptime Error = Int
    def call_once(deinit self) raises Int -> NoneType:
        _ = self.count[].fetch_add(1)
        if self.fail:
            raise 99
        return None


def fiber_test_ready(flag: ArcPointer[Atomic[UInt8]]) raises:
    var deadline = monotonic() + 10_000_000_000
    while flag[].load() == 0:
        if monotonic() > deadline:
            raise Error("fiber did not enter its scope")
        sleep(0.001)


def fiber_test_answer() -> Int:
    return 42


def fiber_test_fail() raises Int -> Int:
    raise 11


@fieldwise_init
struct FiberCancelParent(ReaderAction):
    var token: CancellationToken
    var gate: ArcPointer[Atomic[UInt8]]
    comptime Family = IO[Int]
    comptime Env = IOContext[Int]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Int]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        var deadline = monotonic() + 10_000_000_000
        while self.gate[].load() == 0 and monotonic() < deadline:
            if context.canceled():
                return None
            sleep(0.001)
        self.token.cancel()
        while not context.canceled() and monotonic() < deadline:
            sleep(0.001)
        return None


@fieldwise_init
struct FiberEnterJoin[P: ReaderAction](ReaderAction):
    var join: Self.P
    var gate: ArcPointer[Atomic[UInt8]]
    comptime Family = Self.P.Family
    comptime Env = Self.P.Env
    comptime Value = Self.P.Value
    comptime Out[o: ImmOrigin] = Self.P.Out[o]
    comptime Error[o: ImmOrigin] = Self.P.Error[o]
    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) raises Self.Error[o] -> Self.Out[o]:
        self.gate[].store(1)
        return self.join^.run(context)



@fieldwise_init
struct FiberObservedState[S: Movable & Deinitable](Movable):
    var state: ArcPointer[Self.S]
    var count: Int


@fieldwise_init
struct FiberObserveLifetime[S: Movable & Deinitable](OnceThunk):
    var state: ArcPointer[Self.S]
    var entered: ArcPointer[Atomic[UInt8]]
    var release: ArcPointer[Atomic[UInt8]]
    comptime Out = FiberObservedState[Self.S]
    def call_once(deinit self) -> Self.Out:
        var deadline = monotonic() + 10_000_000_000
        while self.entered[].load() == 0 and monotonic() < deadline:
            sleep(0.001)
        var count = Int(self.state.count())
        self.release[].store(1)
        # Retain this observer's reference in its outcome, so even the buggy
        # early-drop implementation is tested without accessing freed memory.
        return FiberObservedState(self.state^, count)


@fieldwise_init
struct FiberLifetimeFinalizer(OnceThunk):
    var entered: ArcPointer[Atomic[UInt8]]
    var release: ArcPointer[Atomic[UInt8]]
    comptime Out = NoneType
    def call_once(deinit self) -> NoneType:
        self.entered[].store(1)
        var deadline = monotonic() + 10_000_000_000
        while self.release[].load() == 0 and monotonic() < deadline:
            sleep(0.001)
        return None


def fiber_test_linux() raises:
    var count = ArcPointer(Atomic(Int(0)))
    var ready = ArcPointer(Atomic(UInt8(0)))
    var child = unsafe_start(guarantee(FiberTestWait(ready.copy()), delay[Int](FiberTestFinish(count.copy(), False))))
    fiber_test_ready(ready)
    assert_true(not child.done())
    child.request_cancel()
    assert_true(not child^.join())
    assert_equal(count[].load(), 1)

    ready[].store(0)
    var dropped = unsafe_start(guarantee(FiberTestWait(ready.copy()), delay[Int](FiberTestFinish(count.copy(), False))))
    fiber_test_ready(ready)
    _ = dropped^
    assert_equal(count[].load(), 2)

    ready[].store(0)
    var unentered = unsafe_start(guarantee(FiberTestWait(ready.copy()), delay[Int](FiberTestFinish(count.copy(), False))))
    fiber_test_ready(ready)
    var unentered_join = unentered^.join_io()
    _ = unentered_join^
    assert_equal(count[].load(), 3)

    var failed = unsafe_start(guarantee(delay[Int](fiber_test_fail), delay[Int](FiberTestFinish(count.copy(), True))))
    var outcome = failed^.join()
    var result = outcome.take()
    var failure = result^._take_err()
    assert_true(not failure.canceled)
    var errors = failure^.into_errors()
    var values = errors^.into_list()
    assert_equal(values, [11, 99])
    assert_equal(count[].load(), 4)

    var succeeded = unsafe_start(delay[Int](fiber_test_answer))
    var joined = run_io(succeeded^.join_io())
    var success = joined.take()
    assert_equal(success^._take_ok(), 42)

    var token = CancellationToken()
    var gate = ArcPointer(Atomic(UInt8(0)))
    var canceled = unsafe_start(guarantee(FiberCancelParent(token.copy(), gate.copy()), delay[Int](FiberTestFinish(count.copy(), True))))
    var parent = FiberEnterJoin(canceled^.join_io(), gate.copy())
    var canceled_outcome = run_io(parent^, token)
    var canceled_result = canceled_outcome.take()
    var canceled_failure = canceled_result^._take_err()
    assert_true(canceled_failure.canceled)
    var canceled_errors = canceled_failure^.into_errors()
    assert_equal(canceled_errors.first(), 99)
    assert_equal(count[].load(), 5)

    ready[].store(0)
    var entered = ArcPointer(Atomic(UInt8(0)))
    var release = ArcPointer(Atomic(UInt8(0)))
    var protected = unsafe_start(guarantee(FiberTestWait(ready.copy()), delay[Int](FiberLifetimeFinalizer(entered.copy(), release.copy()))))
    fiber_test_ready(ready)
    var state_owner = protected._thread.state().copy()
    var observer = unsafe_start(delay[Error](FiberObserveLifetime(state_owner^, entered.copy(), release.copy())))
    _ = protected^
    var observation = observer^.join()
    var observation_result = observation.take()
    var observed = observation_result^._take_ok()
    # Both Fiber and observer must own the allocation while the finalizer runs.
    assert_equal(observed.count, 2)
    _ = observed^


def main() raises:
    comptime if CompilationTarget.is_linux():
        fiber_test_linux()
    else:
        var rejected = False
        try:
            _ = unsafe_start(delay[Int](fiber_test_answer))
        except:
            rejected = True
        assert_true(rejected)
