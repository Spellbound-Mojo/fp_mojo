# error: pipeline: a shared call requires a reusable shared stage
from fp.functions import flow, Identity
from fp.callables import MutableUnary


@fieldwise_init
struct C(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var x: Int) -> Int:
        return 1


def main():
    var f = flow(C(), Identity[Int]())
    _ = f.call(1)
