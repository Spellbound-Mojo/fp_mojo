# error: violated constraint
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import ValidationFamily,ListMonoid
from fp.callables import Unary
@fieldwise_init
struct F(Unary):
    comptime Arg=Int
    comptime Out=Int
    def call(self,var x:Int)->Int: return x
def main(): _ = pipeline(Result[F,String](Ok(F()))).ap(Result[Int,Int](Ok(1))).get()
