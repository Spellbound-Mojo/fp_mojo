"""Owned native delay ends admission loans while retaining independent origins."""
from std.os import abort
from fp.effects import Outcome, EffectFailure, fold_outcome
from std.memory import ArcPointer
from fp.effects.async_runtime import delay, run


@fieldwise_init
struct Guard(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


def unopened(drops: ArcPointer[Int], calls: ArcPointer[Int]):
    var guard = Guard(drops.copy())
    def callback() {var guard^, calls} -> Int:
        calls[] += 1
        return guard.drops[]
    var recipe = delay[Int](callback^)
    check(calls[] == 0 and drops[] == 0, "owned callback remains deferred")
    _ = recipe^


def external[o: ImmOrigin](ref[o] owner: List[Int]):
    var view = Span(owner)
    def borrowed() {view} -> Span[Int, o]:
        return view
    var kept = run(delay[Int](borrowed))
    def first(var result: Span[Int, o]) -> Int:
        return result[0]
    var value = fold_outcome(kept^, first, failure, canceled)
    check(value == 42, "result retains the independent external origin")


def main():
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    unopened(drops, calls)
    check(drops[] == 1 and calls[] == 0, "unopened recipe destroys its capture without executing")
    var guard = Guard(drops.copy())
    def callback() {var guard^, calls} -> Int:
        calls[] += 1
        return 41 + guard.drops[]
    var recipe = delay[Int](callback^)
    var outcome = run(recipe^)
    check(take_int(outcome^) == 42 and drops[] == 2 and calls[] == 1, "entered callback runs once and drops its capture")
    var owner: List[Int] = [42]
    external(owner)
    print("application ownership: moved native captures, unopened discard, one execution, external origins")


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
