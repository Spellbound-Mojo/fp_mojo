# error: pipeline: a mutable call cannot reuse a consuming stage
from fp.functions import flow, Identity
from fp.callables import OnceUnary
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int: return value
def main():
    var chain = flow(Identity[Int](), Identity[Int]()).then(Once())
    _ = chain.call_mut(1)
