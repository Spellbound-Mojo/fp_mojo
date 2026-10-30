"""IO owns its callbacks: deferred, discarded unopened, run once; external origins travel in T."""
from std.os import abort
from std.memory import ArcPointer
from fp.callables import OnceThunk
from fp.effects import Outcome, EffectFailure, fold_outcome
from fp.effects.async_runtime import IO, run


@fieldwise_init
struct Guard(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct Count(OnceThunk):
    var guard: Guard
    var calls: ArcPointer[Int]
    comptime Out = Int
    def call_once(deinit self) -> Int:
        self.calls[] += 1
        return 41 + self.guard.drops[]


@fieldwise_init
struct View[o: ImmOrigin](OnceThunk):
    var view: Span[Int, Self.o]
    comptime Out = Span[Int, Self.o]
    def call_once(deinit self) -> Self.Out:
        return self.view


def unopened(drops: ArcPointer[Int], calls: ArcPointer[Int]):
    var io = IO[Int, Int].delay(Count(Guard(drops.copy()), calls.copy()))
    check(calls[] == 0 and drops[] == 0, "owned callback remains deferred")
    _ = io^


def external[o: ImmOrigin](ref[o] owner: List[Int]):
    # The callback's origin is also the value's, so the IO's type keeps it.
    var kept = run(IO[Span[Int, o], Int].delay(View(Span(owner))))
    def first(var result: Span[Int, o]) -> Int:
        return result[0]
    var value = fold_outcome(kept^, first, failure, canceled)
    check(value == 42, "result retains the independent external origin")


def main():
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    unopened(drops, calls)
    check(drops[] == 1 and calls[] == 0, "an unopened IO destroys its callback without running it")
    var outcome = run(IO[Int, Int].delay(Count(Guard(drops.copy()), calls.copy())))
    check(take_int(outcome^) == 42 and drops[] == 2 and calls[] == 1, "an entered callback runs once and drops its state")
    var owner: List[Int] = [42]
    external(owner)
    print("io ownership: owned callback state, unopened discard, one execution, external origins")


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def success(value: Int) -> Int:
    return value


def failure(var value: EffectFailure[Int]) -> Int:
    abort("unexpected failure")


def canceled() -> Int:
    abort("unexpected cancellation")


def take_int(var outcome: Outcome[Int, Int]) -> Int:
    return fold_outcome(outcome^, success, failure, canceled)
