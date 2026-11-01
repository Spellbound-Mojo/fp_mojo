"""Accumulating operations preserve ordered errors and usable Result continuations."""
from fp.functions import pipeline
from fp.algebra import StringMonoid, ValidationFamily, ListMonoid
from fp.data import Result,Ok,Err
from std.testing import assert_equal

def add(var a:Int,var b:Int)->Int: return a+b
def check(var value:Int)->Result[Int,List[String]]:
    if value % 2==1: return Err(List[String]([String(value)]))
    return Ok(value)
def dependent(var values:List[Int])->Result[Int,List[String]]: return Ok(len(values))
def main() raises:
    var failed=pipeline(Result[Int,List[String]](Err(List[String](["a"])))).par_map_n((Result[Int,List[String]](Err(List[String](["b"]))),),add).get()
    assert_equal(failed._err().value,List[String](["a","b"]))
    var successful=pipeline(Result[Int,String](Ok(2))).par_map_n[StringMonoid]((Result[Int,String](Ok(3)),),add).get()
    assert_equal(successful._ok().value,5)
    var product=pipeline(Result[Int,List[String]](Ok(2))).par_product_n((Result[String,List[String]](Ok(String("x"))),)).get()
    assert_equal(product._ok().value[1],"x")
    var one=pipeline(Result[Int,List[String]](Ok(3))).par_product_n(Tuple()).get()
    assert_equal(one._ok().value[0],3)
    assert_equal(pipeline(List[Int]([1,2,3])).par_traverse(check).get()._err().value,List[String](["1","3"]))
    var pointer:def(var Int) thin ->Result[Int,List[String]]=check
    assert_equal(pipeline(List[Int]([1,2,3])).par_traverse(pointer).get()._err().value,List[String](["1","3"]))
    assert_equal(pipeline(List[Int]([2,4])).par_traverse(check).flat_map(dependent).get()._ok().value,2)
    assert_equal(pipeline(List[Result[Int,List[String]]]([Result[Int,List[String]](Ok(2))])).par_sequence().get()._ok().value,List[Int]([2]))
    assert_equal(pipeline(List[Result[Int,List[String]]]()).par_sequence().get()._ok().value,List[Int]())
    assert_equal(Bool(pipeline(Optional[Result[Int,List[String]]]()).par_sequence().get()._ok().value),False)
    assert_equal(pipeline(Result[Int,List[String]](Ok(1))).par_map_n(Tuple(),only).get()._ok().value,1)
    var all_eight=pipeline(Result[Int,List[String]](Ok(1))).par_map_n((Result[Int,List[String]](Ok(2)),Result[Int,List[String]](Ok(3)),Result[Int,List[String]](Ok(4)),Result[Int,List[String]](Ok(5)),Result[Int,List[String]](Ok(6)),Result[Int,List[String]](Ok(7)),Result[Int,List[String]](Ok(8))),eight).get()
    assert_equal(all_eight._ok().value,36)
    # An explicitly selected accumulation family remains selected after products.
    var explicit=pipeline[ValidationFamily[ListMonoid[String]]](Result[Int,List[String]](Ok(2))).par_product_n(Tuple()).fill(3).get()
    assert_equal(explicit._ok().value,3)

def only(var value:Int)->Int: return value
def eight(var a:Int,var b:Int,var c:Int,var d:Int,var e:Int,var f:Int,var g:Int,var h:Int)->Int:
    return a+b+c+d+e+f+g+h
