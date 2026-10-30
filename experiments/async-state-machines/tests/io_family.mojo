"""IO selects its Async family: Pipeline, tail recursion, traversal, collection, products and attempt."""
from std.iter import Iterator
from std.memory import ArcPointer
from fp.algebra import pure, product, tail_rec_m, map, flat_map, traverse, ListFamily
from fp.iteration import traverse as collect
from fp.callables import MutableUnary
from fp.functions import pipeline
from fp.data import ControlFlow, Continue, Break
from fp.effects import EffectFailure
from fp.effects._async.engine import Async
from state_machine import IO, run
from foundation import check

comptime DEPTH = 100_000


def step(value: Int) -> IO[ControlFlow[Int, Int], Int]:
    var control = ControlFlow[Int, Int](Break(value)) if value == DEPTH else ControlFlow[Int, Int](Continue(value + 1))
    return IO[ControlFlow[Int, Int], Int].pure(control^)


def twice(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value * 2)


def increment(value: Int) -> Int:
    return value + 1


def halve(value: Int) raises Int -> Int:
    if value % 2:
        raise value
    return value // 2


def recover(var failure: EffectFailure[Int]) -> IO[Int, Int]:
    var errors = failure^.into_errors().into_list()
    return IO[Int, Int].pure(errors[0] * 100)


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
    comptime Out = IO[Int, Int]
    comptime Error = Int

    def call_mut(mut self, var value: Int) raises Int -> Self.Out:
        self.calls[] += 1
        if value == 2:
            raise 22
        return IO[Int, Int].pure(value)


def selection():
    var result = run(pipeline(pure[Async[Int]](20)).flat_map(twice).map(increment).get())
    check(result.take()._take_ok() == 41, "Pipeline selects the IO family from the carrier")
    var mapped = run(flat_map[Async[Int]](twice, map[Async[Int]](increment, IO[Int, Int].pure(4))))
    check(mapped.take()._take_ok() == 10, "free map and flat_map own plain functions for IO")
    var raised = run(pipeline(map[Async[Int]](halve, IO[Int, Int].pure(7))).handle_error_with(recover).get())
    check(raised.take()._take_ok() == 700, "a native callback error becomes the IO failure and recovers")
    var pair = run(product[Async[Int]](IO[Int, Int].pure(3), IO[Int, Int].pure(4)))
    var values = pair.take()._take_ok()
    check(values[0] == 3 and values[1] == 4, "product sequences two IOs")


def attempt_materializes():
    var ok = run(pipeline(IO[Int, Int].pure(5)).attempt().get())
    check(ok.take()._take_ok()._take_ok() == 5, "attempt wraps success")
    var failed = run(pipeline(IO[Int, Int].raise_error(9)).attempt().get())
    var failure = failed.take()._take_ok()._take_err()
    check(not failure.canceled and failure^.into_errors().into_list()[0] == 9, "attempt materializes the failure")


def iteration():
    var looped = run(tail_rec_m[Async[Int]](step, 0))
    check(looped.take()._take_ok() == DEPTH, "tail_rec_m runs in constant stack")
    var values = List[Int]()
    for index in range(DEPTH):
        values.append(index)
    var mapped = run(traverse[ListFamily, Async[Int]](twice, values^))
    var list = mapped.take()._take_ok()
    check(len(list) == DEPTH and list[0] == 0 and list[DEPTH - 1] == 2 * (DEPTH - 1), "traversal keeps source order")
    var pulls = ArcPointer(0)
    var calls = ArcPointer(0)
    var program = collect[Async[Int]](StopAtTwo(calls.copy()), Source(pulls.copy()))
    check(pulls[] == 0 and calls[] == 0, "collection defers source pulls and callbacks")
    var failed = run(program^)
    check(pulls[] == 2 and calls[] == 2, "a failed collection stops pulling and calling")
    check(failed.take()._take_err().into_errors().into_list()[0] == 22, "the callback error keeps its exact type and value")


def main():
    selection()
    attempt_materializes()
    iteration()
    print("io family: Pipeline selection, free operations on plain functions, native errors and recovery, product, attempt, constant-stack tail_rec_m and traversal, deferred collection")
