# error: constraint
from fp.effects import Ref
from fp.callables import OnceUnary
@fieldwise_init
struct Raising(OnceUnary):
    comptime Arg=Int
    comptime Out=Tuple[Int,Int]
    comptime Error=String
    def call_once(deinit self,var value:Int) raises String -> Self.Out:raise String("lost")
def main():
    _=Ref(1).modify[String,Int](Raising())
