# error: constraint
from fp.iteration import find_map_effect
from fp.algebra import OptionalFamily
from fp.callables import OnceUnary
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg=Int
    comptime Out=Optional[Optional[Int]]
    def call_once(deinit self,var value:Int)->Self.Out:return Optional(Optional(value))
def main(): _=find_map_effect[OptionalFamily](Once(),range(3))
