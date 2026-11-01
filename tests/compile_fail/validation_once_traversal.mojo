# error: no matching method in call to 'par_traverse'
from fp.callables import OnceUnary
from fp.functions import pipeline
from fp.data import Result,Ok
@fieldwise_init
struct Once(OnceUnary):
    comptime Arg=Int
    comptime Out=Result[Int,List[String]]
    def call_once(deinit self,var arg:Int)->Self.Out:return Ok(arg)
def main():
    _=pipeline(List[Int]([1,2])).par_traverse(Once())
