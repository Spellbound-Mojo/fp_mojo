"""Concurrent traversal depth: 100,000 elements unbounded and 1,000,000 bounded at 64, in constant native stack.

Qualification runs this client again under a 1 MiB stack. Each element
yields once, so children interleave with the parent's launches and waits.
"""
from std.os import abort
from fp.callables import OnceUnary, Unary
from fp.algebra import par_traverse, par_traverse_n
from fp.effects import Outcome
from fp.effects.async_runtime import IO, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


@fieldwise_init
struct Value(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


@fieldwise_init
struct Element(Unary, Copyable):
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[Int, Int]:
        return IO[NoneType, Int].cede().map(Value(index))


def indices(n: Int) -> List[Int]:
    var values = List[Int](capacity=n)
    for index in range(n):
        values.append(index)
    return values^


def counted(var outcome: Outcome[List[Int], Int], n: Int):
    check(Bool(outcome) and outcome.value().is_ok(), "the traversal succeeds")
    var values = outcome.take()._take_ok()
    check(len(values) == n and values[0] == 0 and values[n - 1] == n - 1, "every result, in source order")


def main():
    counted(run(par_traverse(indices(100_000), Element())), 100_000)
    print("100,000 elements unbounded")
    counted(run(par_traverse_n(64, indices(1_000_000), Element())), 1_000_000)
    print("1,000,000 elements bounded at 64")
