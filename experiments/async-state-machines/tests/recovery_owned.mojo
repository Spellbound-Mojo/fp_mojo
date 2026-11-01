"""Recovery transfers move-only errors and their external origins exactly once."""
from std.memory import ArcPointer
from fp.callables import OnceUnary
from fp.data import Result, Err, NonEmptyList
from fp.effects import IOContext, EffectFailure
from fp.effects._async.engine import IO
from fp.effects._async.kernel import Machine, Step, run
from foundation import check


@fieldwise_init
struct Owned[o: ImmOrigin](Movable):
    var values: Span[Int, Self.o]
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct Source[o: ImmOrigin](Machine):
    comptime Error = Owned[Self.o]
    comptime Value = Self.Error
    var error: Optional[Self.Error]
    var canceled: Bool
    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        return .ready(Optional(Result[Self.Value, EffectFailure[Self.Error]](Err(EffectFailure(NonEmptyList(self.error.take()), self.canceled)))))


@fieldwise_init
struct Handler[o: ImmOrigin](OnceUnary):
    comptime Arg = EffectFailure[Owned[Self.o]]
    comptime Out = IO[Owned[Self.o], Owned[Self.o]]
    def call_once(deinit self, var failure: Self.Arg) -> Self.Out:
        var errors = failure^.into_errors().into_list()
        return Self.Out.pure(errors.pop())


def exercise[o: ImmOrigin](ref[o] values: List[Int]):
    var drops = ArcPointer(0)
    var recovered = run(IO[Owned[o], Owned[o]].lift(Source(Optional(Owned(Span(values), drops.copy())), False)).handle_error_with(Handler[o]()))
    check(drops[] == 0, "recovery must not copy or prematurely destroy an error")
    var value = recovered.take()._take_ok()
    check(value.values[0] == 37, "recovery preserves the external payload origin")
    _ = value^
    check(drops[] == 1, "transferred payload is destroyed once")
    var canceled = run(IO[Owned[o], Owned[o]].lift(Source(Optional(Owned(Span(values), drops.copy())), True)).handle_error_with(Handler[o]()))
    check(drops[] == 1, "canceled error stays owned by the terminal outcome")
    _ = canceled^
    check(drops[] == 2, "canceled error is destroyed once")


def main():
    var values: List[Int] = [37]
    exercise(values)
    print("recovery ownership: move-only errors, external origins, transfer, canceled retention")
