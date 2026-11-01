"""Existing algebra and Pipeline dispatch build IO programs through the Async family."""
from std.memory import ArcPointer
from fp.functions import pipeline
from fp.algebra import pure, map, map2_lazy
from fp.callables import OnceUnary, OnceThunk, as_binary, as_unary
from fp.effects import CancellationToken
from fp.effects._async.engine import Async
from fp.effects._async.kernel import run
from foundation import check, Resource


def twice(value: Int) -> Int:
    return value * 2


def following(value: Int) -> Async[Int].Pure[Int]:
    return pure[Async[Int]](value + 1)


def broken(value: Int) raises Int -> Int:
    raise value + 10


@fieldwise_init
struct Count(OnceUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int:
        self.calls[] += 1
        return value + 1


@fieldwise_init
struct TakeOwned(OnceUnary):
    var owner: Resource
    comptime Arg = Int
    comptime Out = Resource
    def call_once(deinit self, var value: Int) -> Resource:
        return self.owner^


@fieldwise_init
struct RightSide(OnceThunk):
    var calls: ArcPointer[Int]
    comptime Out = Async[Int].Pure[Int]
    def call_once(deinit self) -> Self.Out:
        self.calls[] += 1
        return pure[Async[Int]](2)


def plus(a: Int, b: Int) -> Int:
    return a + b


def main():
    var calls = ArcPointer(0)
    var program = pipeline(pure[Async[Int]](20)).map(Count(calls.copy())).map(twice).flat_map(following).get()
    check(calls[] == 0, "family construction must not call callbacks")
    var result = run(program^)
    check(result.take()._take_ok() == 43 and calls[] == 1, "Pipeline must select Async and sequence callbacks once")
    var failed = map[Async[Int]](pure[Async[Int]](7), as_unary(broken))
    var skipped = run(map2_lazy[Async[Int]](failed^, RightSide(calls.copy()), as_binary(plus)))
    check(calls[] == 1, "failed left side must skip lazy right factory")
    var failure = skipped.take()._take_err()
    check(failure^.into_errors().into_list()[0] == 17, "map must defer and capture the exact native error")
    var selected = run(pipeline(pure[Async[Int]](5)).product_l(pure[Async[Int]](8)).get())
    check(selected.take()._take_ok() == 5, "product_l retains the left value")
    var last = run(pipeline(pure[Async[Int]](5)).product_r(pure[Async[Int]](8)).get())
    check(last.take()._take_ok() == 8, "product_r retains the right value")
    var stats = ArcPointer(List[Int](length=5, fill=0))
    var owned = pipeline(pure[Async[Int]](0)).map(TakeOwned(Resource(String("owned continuation"), stats.copy()))).get()
    var output = run(owned^)
    check(stats[][3] == 0, "family must preserve move-only callback captures")
    _ = output.take()._take_ok()
    check(stats[][3] == 1, "move-only family result destroyed once")
    var token = CancellationToken()
    token.cancel()
    check(not run(pipeline(pure[Async[Int]](0)).map(Count(calls.copy())).get(), token), "cancellation skips unopened callback")
    check(calls[] == 1, "canceled callback must stay unopened")
    print("family: native sequencing, lazy right operands, exact errors, cancellation, owned captures")
