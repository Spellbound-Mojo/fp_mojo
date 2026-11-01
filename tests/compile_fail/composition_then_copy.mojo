# error: cannot be implicitly copied
from fp.functions import flow, Identity
from fp.callables import Unary
@fieldwise_init
struct Stage(Unary):
    comptime Arg = Int
    comptime Out = Int
    var value: Int
    def call(self, var value: Int) -> Int: return value + self.value
def main():
    var stage = Stage(1)
    _ = flow(Identity[Int](), Identity[Int]()).then(stage)
