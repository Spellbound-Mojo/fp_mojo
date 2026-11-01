# error: no matching method in call to 'par_traverse'
from fp.functions import pipeline
from fp.callables import OnceUnary
from fp.data import Result,Ok
@fieldwise_init
struct Step(OnceUnary):
    comptime Arg=Int
    comptime Out=Result[Int,List[String]]
    def call_once(deinit self,var value:Int)->Self.Out: return Ok(value)
def main(): _ = pipeline(List[Int]([1,2])).par_traverse(Step()).get()
