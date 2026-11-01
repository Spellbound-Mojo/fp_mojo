"""Shared sequencing factories retain receiver choice across native families."""
from fp.callables import Thunk,MutableThunk,OnceThunk,mut_ref
from fp.data import Result,Ok,Err
from fp.functions import pipeline
from std.testing import assert_equal
from std.memory import ArcPointer
from fp.algebra import OptionalFamily
from test_context_sequencing_contracts import Create
from test_algebra_third_party import Cell,CellFamily

@fieldwise_init
struct Factory[copyable:Bool=False](Thunk,MutableThunk,OnceThunk,Copyable where copyable):
    comptime Out=Result[Int,String]
    var calls:Int
    def call(self)->Self.Out:return Ok(11)
    def call_mut(mut self)->Self.Out:
        self.calls+=1
        return Ok(22)
    def call_once(deinit self)->Self.Out:return Ok(33)

@fieldwise_init
struct Items(Thunk):
    comptime Out=List[Int]
    def call(self)->Self.Out:return [10,20]

def main() raises:
    var factory=Factory(0)
    assert_equal(Result[Int,String](Ok(4)).followed_by(factory).get_or(0),11)
    assert_equal(Result[Int,String](Ok(4)).before(factory).get_or(0),4)
    assert_equal(Result[Int,String](Err(String("fail"))).before(factory).is_err(),True)
    assert_equal(pipeline(Result[Int,String](Ok(4))).followed_by(factory).get_or(0),11)
    assert_equal(pipeline(Result[Int,String](Ok(4))).before(factory).get_or(0),4)
    assert_equal(pipeline(Result[Int,String](Ok(4))).followed_by(Factory(0)).get_or(0),33)
    assert_equal(pipeline(Result[Int,String](Ok(4))).followed_by(mut_ref(factory)).get_or(0),22)
    assert_equal(factory.calls,1)
    var items=Items()
    var source:List[Int]=[1,2]
    var output=pipeline(source^).followed_by(items).get()
    assert_equal(len(output),4)
    assert_equal(output[0],10)
    assert_equal(output[3],20)
    var copied=Factory[True](0)
    assert_equal(Result[Int,String](Ok(4)).followed_by(copied).get_or(0),11)
    assert_equal(pipeline(Result[Int,String](Ok(4))).followed_by(copied).get_or(0),11)
    assert_equal(copied.calls,0)
    var calls=ArcPointer(0)
    var optional=Create[OptionalFamily](calls)
    assert_equal(pipeline(Optional(3)).before(optional).get().value(),3)
    assert_equal(pipeline(Optional(3)).followed_by(optional).get().value(),7)
    assert_equal(Bool(pipeline(Optional[Int]()).before(optional).get()),False)
    assert_equal(calls[],2)
    var custom=Create[CellFamily](calls)
    assert_equal(pipeline[CellFamily](Cell(3)).before(custom).get().take(),3)
    assert_equal(pipeline[CellFamily](Cell(3)).followed_by(custom).get().take(),7)
    assert_equal(calls[],4)
