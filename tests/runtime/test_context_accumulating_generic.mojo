"""Accumulating native callbacks preserve generic errors without type hints."""
from fp.functions import pipeline
from fp.data import Result,Ok
from std.testing import assert_equal

def mapping[A:Movable & Deinitable,B:Movable & Deinitable,R:Movable & Deinitable,E:Movable & Deinitable,//,F:def(var A,var B) raises E -> R](ref function:F,var left:Result[A,List[String]],var right:Result[B,List[String]]) raises E -> Result[R,List[String]]:
    return pipeline(left^).raising[E]().par_map_n((right^,),function).get()
def traversal[A:Movable & Deinitable,B:Movable & Deinitable,E:Movable & Deinitable,//,F:def(var A) raises E -> Result[B,List[String]]](ref function:F,var values:List[A]) raises E -> Result[List[B],List[String]]:
    return pipeline(values^).raising[E]().par_traverse(function).get()
def add(var a:Int,var b:Int)->Int: return a+b
def present(var a:Int)->Result[String,List[String]]: return Ok(String(a))
def main() raises:
    assert_equal(mapping(add,Result[Int,List[String]](Ok(2)),Result[Int,List[String]](Ok(3)))._ok().value,5)
    assert_equal(traversal(present,List[Int]([1,2]))._ok().value,List[String](["1","2"]))
