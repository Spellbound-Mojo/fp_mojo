"""Named shared default factories retain state and select the shared receiver."""
from fp.data import Result,Ok,Err
from fp.callables import Thunk,MutableThunk,OnceThunk,mut_ref
from fp.functions import pipeline
from std.testing import assert_equal

from test_attempt_once_receivers import Modes

@fieldwise_init
struct CopyModes(Thunk,MutableThunk,OnceThunk,Copyable):
    comptime Out=Int
    var calls:Int
    def call(self)->Int:return 1
    def call_mut(mut self)->Int:
        self.calls+=1
        return 2
    def call_once(deinit self)->Int:return 3

def generic[C:Thunk](factory:C) raises C.Error -> C.Out:
    return Result[C.Out,Int](Err(0)).get_or_else(factory)

def generic_optional[C:Thunk](factory:C) raises C.Error -> C.Out:
    return pipeline(Optional[C.Out]()).get_or_else(factory)


def main() raises:
    var factory=Modes(0)
    assert_equal(Result[Int,Int](Err(9)).get_or_else(factory),1)
    assert_equal(Result[Int,Int](Err(9)).get_or_else(Modes(0)),3)
    assert_equal(Result[Int,Int](Ok(4)).get_or_else(factory),4)
    assert_equal(pipeline(Result[Int,Int](Err(9))).get_or_else(factory),1)
    assert_equal(pipeline(Optional[Int]()).get_or_else(factory),1)
    assert_equal(pipeline(Optional[Int]()).get_or_else(Modes(0)),3)
    assert_equal(pipeline(Optional[Int]()).to_result(factory).swap().get_or(0),1)
    assert_equal(pipeline(Optional[Int]()).to_result(Modes(0)).swap().get_or(0),3)
    assert_equal(pipeline(Optional[Int](4)).to_result(factory).get_or(0),4)
    assert_equal(pipeline(Optional[Int]()).get_or_else(mut_ref(factory)),2)
    assert_equal(factory.calls,1)
    var copied=CopyModes(0)
    assert_equal(Result[Int,Int](Err(9)).get_or_else(copied),1)
    assert_equal(pipeline(Optional[Int]()).get_or_else(copied),1)
    assert_equal(pipeline(Optional[Int]()).to_result(copied).swap().get_or(0),1)
    assert_equal(copied.calls,0)
    assert_equal(Result[Int,Int](Err(9)).get_or_else(mut_ref(factory)),2)
    assert_equal(pipeline(Result[Int,Int](Err(9))).get_or_else(mut_ref(factory)),2)
    assert_equal(pipeline(Optional[Int]()).to_result(mut_ref(factory)).swap().get_or(0),2)
    assert_equal(factory.calls,4)
    assert_equal(generic(factory),1)
    assert_equal(generic_optional(factory),1)
