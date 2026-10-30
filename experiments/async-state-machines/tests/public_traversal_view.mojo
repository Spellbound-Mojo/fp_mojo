"""Iterator views retain the declared Async family and deferred execution."""
from std.iter import Iterator
from std.memory import ArcPointer
from std.os import abort
from fp.callables import Unary
from fp.effects import CancellationToken, EffectFailure, fold_outcome
from fp.effects.async_runtime import Async, Pure, pure, run
from fp.functions import kleisli
from fp.iteration import iterated


@fieldwise_init
struct Source(Iterator):
    var pulls: ArcPointer[Int]
    var current: Int
    var limit: Int
    comptime Element = Int
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[] += 1
        if self.current == self.limit:
            raise StopIteration()
        var value = self.current
        self.current += 1
        return value


@fieldwise_init
struct Produce(Unary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Pure[Int, Int]
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Self.Out:
        self.calls[] += 1
        if value == 2:
            raise 22
        return pure[Int](value + 10)


def check(condition: Bool):
    if not condition:
        abort("public async traversal view contract failed")


def sum_values(var values: List[Int]) -> Int:
    var total = 0
    for value in values:
        total += value
    return total


def ignored(value: NoneType) -> Int:
    return 0


def failed(var error: EffectFailure[Int]) -> Int:
    check(not error.canceled)
    return -error.errors.first()


def canceled() -> Int:
    return -999


def main() raises:
    var calls = ArcPointer(0)
    var pulls = ArcPointer(0)
    var chain = kleisli[Async[Int]](Produce(calls.copy()))
    for count in [0, 2, 5]:
        calls[] = 0
        pulls[] = 0
        var collected = iterated(Source(pulls.copy(), 0, count)).traverse(chain)
        comptime assert type_of(collected).Family == Async[Int]
        check(calls[] == 0 and pulls[] == 0)
        var result = fold_outcome(run(collected^), sum_values, failed, canceled)
        check(result == (-22 if count == 5 else 21 if count == 2 else 0))
        check(calls[] == (3 if count == 5 else count))
        check(pulls[] == (3 if count == 5 else count + 1))
        calls[] = 0
        pulls[] = 0
        var discarded = iterated(Source(pulls.copy(), 0, count)).traverse_void(chain)
        comptime assert type_of(discarded).Family == Async[Int]
        check(calls[] == 0 and pulls[] == 0)
        check(fold_outcome(run(discarded^), ignored, failed, canceled) == (-22 if count == 5 else 0))
        check(calls[] == (3 if count == 5 else count))
        check(pulls[] == (3 if count == 5 else count + 1))
    calls[] = 0
    pulls[] = 0
    var token = CancellationToken()
    token.cancel()
    var unopened = iterated(Source(pulls.copy(), 0, 5)).traverse(chain)
    check(fold_outcome(run(unopened^, token), sum_values, failed, canceled) == -999)
    check(calls[] == 0 and pulls[] == 0)
    print("public traversal views: selected Async family, deferred pulls, reuse, exact errors and cancellation")
