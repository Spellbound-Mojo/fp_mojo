"""Accumulating products and traversals release failed inputs, callbacks and partial results."""
from fp.functions import pipeline
from fp.callables import OnceUnary
from fp.data import Result,Ok,Err
from fp.algebra import ListMonoid
from std.memory import ArcPointer
from std.testing import assert_equal
from fp.algebra import Semigroup

struct CheckedErrors(Semigroup):
    comptime Value = String
    comptime Error = Int
    @staticmethod
    def combine(var first: String, var second: String) raises Int -> String:
        raise 9

@fieldwise_init
struct AccumulatingOwner(Movable):
    var id:Int
    var drops:ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
@fieldwise_init
struct CombineOnce(OnceUnary):
    var capture:AccumulatingOwner
    comptime Arg=Tuple[AccumulatingOwner,AccumulatingOwner]
    comptime Out=Int
    def call_once(deinit self,var values:Self.Arg)->Int:
        return values[0].id+values[1].id

def main() raises:
    var drops=ArcPointer(0)
    var combined=pipeline(Result[AccumulatingOwner,List[String]](Ok(AccumulatingOwner(1,drops)))).par_map_n((Result[AccumulatingOwner,List[String]](Ok(AccumulatingOwner(2,drops))),),CombineOnce(AccumulatingOwner(9,drops))).get()
    assert_equal(combined._ok().value,3); assert_equal(drops[],3)
    drops[]=0
    var skipped=pipeline(Result[AccumulatingOwner,List[String]](Err(List[String](["failed"])))).par_map_n((Result[AccumulatingOwner,List[String]](Ok(AccumulatingOwner(2,drops))),),CombineOnce(AccumulatingOwner(9,drops))).get()
    assert_equal(skipped._err().value,List[String](["failed"])); assert_equal(drops[],2)
    drops[]=0
    var first=List[AccumulatingOwner]()
    first.append(AccumulatingOwner(1,drops))
    var second=List[AccumulatingOwner]()
    second.append(AccumulatingOwner(2,drops))
    var errors=pipeline(Result[Int,List[AccumulatingOwner]](Err(first^))).par_product_n((Result[Int,List[AccumulatingOwner]](Err(second^)),)).get()
    assert_equal(errors._err().value[0].id,1); assert_equal(errors._err().value[1].id,2)
    assert_equal(drops[],0)
    _ = errors^
    assert_equal(drops[],2)
    drops[]=0
    var values=List[AccumulatingOwner]()
    for i in range(3): values.append(AccumulatingOwner(i,drops))
    def check(var value:AccumulatingOwner)->Result[AccumulatingOwner,List[String]]:
        if value.id==1: return Err(List[String](["failed"]))
        return Ok(value^)
    var failed=pipeline(values^).par_traverse(check).get()
    assert_equal(failed._err().value,List[String](["failed"])); assert_equal(drops[],3)
    drops[]=0
    var code=0
    try:
        _ = pipeline(Result[Int,String](Err(String("left")))).par_product_n[CheckedErrors]((Result[Int,String](Err(String("middle"))),Result[AccumulatingOwner,String](Ok(AccumulatingOwner(3,drops))))).get()
    except error: code=error
    assert_equal(code,9); assert_equal(drops[],1)
