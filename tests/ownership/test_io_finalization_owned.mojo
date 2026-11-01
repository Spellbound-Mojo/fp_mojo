"""Finalization borrows live move-only errors and consumes callback captures once."""
from std.memory import ArcPointer
from std.testing import assert_equal
from fp.effects import ExitCase, ScopedIO, DelayContract, delay, run_io, guarantee_case
from fp.callables import OnceThunk


@fieldwise_init
struct FinalizationOwnedError(Movable):
    var text: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct FinalizationOwnedGuard(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct FinalizationOwnedBody(OnceThunk):
    var drops: ArcPointer[Int]
    comptime Out = Int
    comptime Error = FinalizationOwnedError
    def call_once(deinit self) raises Self.Error -> Int:
        raise FinalizationOwnedError("body remains alive through effectful cleanup", self.drops^)


@fieldwise_init
struct FinalizationOwnedRead[o: ImmOrigin](OnceThunk):
    var exit: Pointer[ExitCase[FinalizationOwnedError], Self.o]
    var guard: FinalizationOwnedGuard
    var error_drops: ArcPointer[Int]
    comptime Out = NoneType
    comptime Error = FinalizationOwnedError
    def call_once(deinit self) raises Self.Error -> NoneType:
        if self.exit[].failure().value().errors.first().text != "body remains alive through effectful cleanup" or self.error_drops[] != 0:
            raise FinalizationOwnedError("invalid error lifetime", self.error_drops^)
        _ = self.guard^
        raise FinalizationOwnedError("cleanup error retained alongside body", self.error_drops^)


@fieldwise_init
struct FinalizationOwnedObserver(ScopedIO):
    var guard: FinalizationOwnedGuard
    var error_drops: ArcPointer[Int]
    comptime Input = ExitCase[FinalizationOwnedError]
    comptime Value = NoneType
    comptime Error = FinalizationOwnedError
    comptime Action[o: ImmOrigin] = DelayContract[FinalizationOwnedRead[o], FinalizationOwnedError].Out
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) -> Self.Action[o]:
        return delay[FinalizationOwnedError](FinalizationOwnedRead(Pointer(to=value), self.guard^, self.error_drops^))


def main() raises:
    var errors = ArcPointer(0)
    var captures = ArcPointer(0)
    var observer = FinalizationOwnedObserver(FinalizationOwnedGuard(captures.copy()), errors.copy())
    var body = delay[FinalizationOwnedError](FinalizationOwnedBody(errors.copy()))
    var output = run_io(guarantee_case(body^, observer^))
    assert_equal(captures[], 1)
    assert_equal(errors[], 0)
    var failed = output.take()
    var failure = failed^._take_err()
    var stored = failure^.into_errors()
    var values = stored^.into_list()
    assert_equal(len(values), 2)
    assert_equal(values[0].text, "body remains alive through effectful cleanup")
    assert_equal(values[1].text, "cleanup error retained alongside body")
    _ = values^
    assert_equal(errors[], 2)
