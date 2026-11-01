"""Mixed thin functions and library handlers preserve receiver selection."""
from fp.data import Result,Ok,Err
from fp.callables import BorrowSignature,as_unary,mut_ref,Unary,BorrowCallable
from test_result_fold_receivers import Shared,Mutable,Modes
from std.testing import assert_equal

def native(value:Int)->Int: return value+10
def typed(value:Int) raises Int -> Int:
    if value<0: raise value
    return value+10

def forwarded[X:Movable & Deinitable,C:Unary](callback:def(var Int) raises X thin -> Int,handler:C) raises (C.Error if X==Never else X) -> Int where C.Arg==Int and C.Out==Int and C.Error==Never:
    return Result[Int,Int](Ok(4)).fold_owned(callback,handler)

def forwarded_borrow[X:Movable & Deinitable,C:BorrowCallable](callback:def(Int) raises X thin -> Int,handler:C) raises (X if C.Failure==Never else C.Failure) -> C.Result where C.Payload==Int and C.Result==Int and C.Failure==Never:
    return Result[Int,Int](Err(4)).fold(handler,callback)


def main() raises:
    var callback=Shared(2)
    var subject=Result[Int,Int](Ok(4))
    assert_equal(subject.fold(callback,native),6)
    assert_equal(subject.fold(native,callback),14)
    assert_equal(subject.fold(Modes(0),native),3)
    assert_equal(subject.fold(native,Modes(0)),14)
    assert_equal(subject^.fold_owned(callback,native),6)
    assert_equal(Result[Int,Int](Err(4)).fold_owned(native,callback),6)
    var offset=20
    def captured(value:Int) {offset} -> Int: return value+offset
    assert_equal(Result[Int,Int](Err(4)).fold(callback,BorrowSignature[Int,Int].capture(captured)),24)
    assert_equal(Result[Int,Int](Ok(4)).fold_owned(as_unary(captured),callback),24)
    var handler=Mutable(0,False)
    var result:Int
    try:
        result=Result[Int,Int](Ok(4)).fold(mut_ref(handler),typed)
    except: raise Error("unexpected")
    assert_equal(result,5)
    assert_equal(handler.calls,1)
    var caught=0
    try:
        _=Result[Int,Int](Err(-7)).fold_owned(callback,typed)
    except error:
        comptime assert type_of(error)==Int
        caught=error
    assert_equal(caught,-7)
    var generic:Int
    try:
        generic=forwarded(typed,callback)+forwarded_borrow(typed,callback)
    except: raise Error("unexpected forwarding failure")
    assert_equal(generic,28)
