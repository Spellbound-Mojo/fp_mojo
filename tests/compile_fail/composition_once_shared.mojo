# error: pipeline: a mutable call cannot reuse a consuming stage
from fp.functions import flow, Identity
from fp.callables import OnceUnary


@fieldwise_init
struct C(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var x: Int) -> Int:
        return 1


def main():
    var f = flow(C(), Identity[Int]())
    _ = f.call_mut(1)
