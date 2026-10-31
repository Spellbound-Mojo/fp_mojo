# error: constraint
from fp.functions import pipeline
from fp.data import Result,Ok
from fp.callables import Unary
@fieldwise_init
struct NaryView[o: ImmOrigin](Unary):
    comptime Arg=Tuple[Int,Span[Int,Self.o],Int]
    comptime Out=Int
    def call(self,var arg:Self.Arg) -> Int: return arg[1][0]
def bad(left:List[Int],right:List[Int]):
    _=pipeline(Result[Int,String](Ok(1))).map_n((Result[Span[Int,origin_of(right)],String](Ok(Span(right))),Result[Int,String](Ok(3))),NaryView[origin_of(left)]())
def main(): bad([1],[2])
