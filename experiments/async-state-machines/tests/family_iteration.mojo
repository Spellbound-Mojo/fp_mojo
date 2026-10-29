"""Generic tail recursion and traversal share the canonical iterative owner."""
from std.iter import Iterator
from std.memory import ArcPointer
from fp.algebra import pure, tail_rec_m, traverse, ListFamily
from fp.iteration import traverse as collect
from fp.callables import MutableUnary
from fp.effects._async.family import Async
from fp.effects._async.kernel import run
from fp.data import ControlFlow, Continue, Break
from foundation import check


def step(value: Int) -> Async[Int].Pure[ControlFlow[Int, Int]]:
    var control = ControlFlow[Int, Int](Break(value)) if value == 1000 else ControlFlow[Int, Int](Continue(value + 1))
    return pure[Async[Int]](control^)


def twice(value: Int) -> Async[Int].Pure[Int]:
    return pure[Async[Int]](value * 2)


@fieldwise_init
struct Source(Iterator):
    var pulls: ArcPointer[Int]
    comptime Element = Int
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[] += 1
        if self.pulls[] > 3:
            raise StopIteration()
        return self.pulls[]


@fieldwise_init
struct StopAtTwo(MutableUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Async[Int].Pure[Int]
    comptime Error = Int
    def call_mut(mut self, var value: Int) raises Int -> Self.Out:
        self.calls[] += 1
        if value == 2:
            raise 22
        return pure[Async[Int]](value)


def main():
    var result = run(tail_rec_m[Async[Int]](step, 0))
    check(result.take()._take_ok() == 1000, "generic tail_rec_m must finish through Loop")
    var values: List[Int] = [1, 2, 3]
    var mapped = run(traverse[ListFamily, Async[Int]](twice, values^))
    check(mapped.take()._take_ok() == List[Int]([2, 4, 6]), "traversal must retain source order")
    var pulls = ArcPointer(0)
    var calls = ArcPointer(0)
    var program = collect[Async[Int]](StopAtTwo(calls.copy()), Source(pulls.copy()))
    check(pulls[] == 0 and calls[] == 0, "fold must defer source pulls and callbacks")
    var failed = run(program^)
    check(pulls[] == 2 and calls[] == 2, "failed traversal must stop pulling and calling")
    var failure = failed.take()._take_err()
    check(failure^.into_errors().into_list()[0] == 22, "loop callback error must retain exact type and value")
    print("family iteration: tail_rec_m, ordered traversal, deferred pulls, failure short circuit")
