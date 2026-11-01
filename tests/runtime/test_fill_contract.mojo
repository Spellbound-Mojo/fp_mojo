"""Structural contracts retain exact families, construction errors and deferred runs."""
from fp.algebra import ListFamily, OptionalFamily, ResultFamily
from fp.functions import pipeline,pipeline_values
from fp.data import Result,Ok
from fp.effects import Reader,run
from algebra_support.fill_contracts import filled,continued,discarded,refilled,Failing
from std.testing import assert_equal

@fieldwise_init
struct Box(Movable):
    var value:Int

def length(var value:String)->Int:return value.byte_length()
def fail(var value:Int) raises Int -> Int:raise value

def main() raises:
    var optional=filled[OptionalFamily](Optional(1),Box(7))
    assert_equal(optional.take().value,7)
    assert_equal(filled[ListFamily](List[Int]([1,2]),3),[3,3])
    var result=filled[ResultFamily[String]](Result[Int,String](Ok(1)),Box(8))
    assert_equal(result^.get_or(Box(0)).value,8)
    assert_equal(continued[OptionalFamily](Optional(1),Box(9)).get_or(Box(0)).value,9)
    comptime R=Reader[Int]
    var pending=filled[R](R.pure(1),Box(10))
    assert_equal(run[R](pending^,0).value,10)
    assert_equal(Bool(discarded[OptionalFamily](Optional(1))),True)
    assert_equal(len(discarded[ListFamily](List[Int]([1,2]))),2)
    var empty=discarded[R](R.pure(1))
    _=run[R](empty^,0)
    var dictionary=Dict[String,Int]()
    dictionary["key"]=1
    var selected=refilled(pipeline_values(dictionary^).raising[Int](),String("new"))
    comptime assert type_of(selected).E==Int
    assert_equal(selected^.map(length).get()["key"],3)
    var code=0
    try:_=filled[Failing](17,Box(1))
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,17)
    var failing=pipeline[R](R.pure(19)).raising[Int]().map(fail).get()
    var delayed=filled[R](failing^,Box(1))
    try:_=run[R](delayed^,0)
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,19)
