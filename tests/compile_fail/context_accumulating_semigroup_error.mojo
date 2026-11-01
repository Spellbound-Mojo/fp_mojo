# error: no matching method
from fp.functions import pipeline
from fp.data import Result,Ok
from fp.algebra import Semigroup
struct CombineErrors(Semigroup):
    comptime Value=String
    comptime Error=Int
    @staticmethod
    def combine(var first:String,var second:String) raises Int ->String: return first^+second^
def callback(var first:Int,var second:Int) raises String ->Int: raise String("bad")
def main(): _ = pipeline(Result[Int,String](Ok(1))).raising[String]().par_map_n[CombineErrors]((Result[Int,String](Ok(2)),),callback).get()
