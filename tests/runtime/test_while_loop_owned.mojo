"""Ordinary while loops own repeatable bodies without changing shared calls."""
from fp.control import while_loop
from fp.callables import Unary, MutableUnary, BorrowCallContract, UnaryContract, BorrowSignature, mut_ref
from test_while_mutable_predicate import Predicate, Body, Modes, below_four, ThrowingBody, ThrowingPredicate
from std.testing import assert_equal
@fieldwise_init
struct BodyModes(Unary,MutableUnary):
    comptime Arg=Int
    comptime Out=Int
    var calls:Int
    def call(self,var value:Int)->Int: return value+1
    def call_mut(mut self,var value:Int)->Int:
        self.calls += 1
        return value+2

def main() raises:
    assert_equal(while_loop(Predicate(0),Body(0),0),6)
    var predicate=Predicate(0)
    var body=Body(0)
    assert_equal(while_loop(mut_ref(predicate),mut_ref(body),0),6)
    assert_equal(predicate.calls,4)
    assert_equal(body.calls,3)
    assert_equal(while_loop(below_four,Body(0),0),4)
    var pointer:def(Int) thin -> Bool=below_four
    assert_equal(while_loop(pointer,Body(0),0),4)
    var both=BodyModes(0)
    var named=Modes(0)
    assert_equal(while_loop(named,both,0),4)
    assert_equal(both.calls,0)
    assert_equal(named.calls,0)
    assert_equal(while_loop(named,both^,0),4)
    assert_equal(while_loop(named^,BodyModes(0),0),6)
    var limit=6
    def captured(value:Int) {limit} -> Bool: return value<limit
    var view=BorrowSignature[Int,Bool].capture(captured)
    assert_equal(while_loop(view,Body(0),0),6)
    var caught=0
    try:
        _=while_loop(ThrowingPredicate(0,2),ThrowingBody(0,0),0)
    except error:
        comptime assert type_of(error)==Int
        caught=error
    assert_equal(caught,-7)
    generic_and_native()


def forward[P:BorrowCallContract & Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var predicate:P,var body:F,var initial:F.Arg) raises F.Error -> F.Arg where P.Payload==F.Arg and P.Result==Bool and P.Failure==F.Error and F.Out==F.Arg:
    return while_loop[E=F.Error](predicate^,body^,initial^)

def forward_pure[P:BorrowCallContract & Movable & Deinitable,F:UnaryContract & Movable & Deinitable](var predicate:P,var body:F,var initial:F.Arg) raises F.Error -> F.Arg where P.Payload==F.Arg and P.Result==Bool and P.Failure==Never and F.Out==F.Arg:
    return while_loop[E=F.Error](predicate^,body^,initial^)

def checked(value:Int) raises Int -> Bool:
    if value<0: raise -9
    return value<4

def generic_and_native() raises:
    assert_equal(forward(Predicate(0),Body(0),0),6)
    for scenario in range(3):
        var caught=0
        var body=ThrowingBody(0,2)
        try:
            if scenario==0: _=forward_pure(Predicate(0),mut_ref(body),0)
            elif scenario==1: _=while_loop(checked,mut_ref(body),-1)
            else: _=while_loop(checked,mut_ref(body),0)
        except error:
            comptime assert type_of(error)==Int
            caught=error
        assert_equal(caught,-9 if scenario==1 else -8)
        assert_equal(body.calls,0 if scenario==1 else 2)
