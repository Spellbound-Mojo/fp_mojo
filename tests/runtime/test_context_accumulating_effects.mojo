"""Accumulation distinguishes stored errors from immediate native errors."""
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from fp.algebra import Semigroup
from std.memory import ArcPointer
from std.testing import assert_equal

struct CheckedErrors(Semigroup):
    comptime Value=String
    comptime Error=Int
    @staticmethod
    def combine(var first:String,var second:String) raises Int -> String:
        raise 9

def add(var a:Int,var b:Int)->Int: return a+b
def only(var a:Int)->Int: return a

def main() raises:
    var code=0
    try: _ = pipeline(Result[Int,String](Err(String("a")))).par_map_n[CheckedErrors]((Result[Int,String](Err(String("b"))),),add).get()
    except error: code=error
    assert_equal(code,9)
    # A single operand never invokes the error combiner and raises Never.
    assert_equal(pipeline(Result[Int,String](Ok(3))).par_map_n[CheckedErrors](Tuple(),only).get()._ok().value,3)
    def one_failure(var value:Int) raises String ->Int: raise String("callback")
    var message=String()
    try: _ = pipeline(Result[Int,String](Ok(3))).raising[String]().par_map_n[CheckedErrors](Tuple(),one_failure).get()
    except error: message=error^
    assert_equal(message,"callback")
    var calls=ArcPointer(0)
    def checked(var value:Int) raises Int {calls} -> Result[Int,List[String]]:
        calls[] += 1
        if value==2: raise value
        return Err(List[String]([String(value)]))
    try: _ = pipeline(List[Int]([1,2,3])).raising[Int]().par_traverse(checked).get()
    except error: code=error
    assert_equal(code,2); assert_equal(calls[],2)
    def present(var value:Int)->Result[Int,List[String]]: return Ok(value)
    var retained=pipeline(Result[Int,String](Err(String("source")))).par_traverse(present).get()
    assert_equal(retained._ok().value._err().value,"source")
