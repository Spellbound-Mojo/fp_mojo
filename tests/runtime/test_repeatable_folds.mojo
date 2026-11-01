from fp.iteration import fold_left, fold_until, reduce, reduce_optional, EmptyReductionError, ReductionStepError, iterated
from fp.callables import MutableBinary
from fp.data import Break,Continue,ControlFlow
from std.testing import assert_equal
@fieldwise_init
struct Add(MutableBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    var calls:Int
    def call_mut(mut self,var a:Int,var b:Int)->Int:
        self.calls+=1
        return a+b+self.calls
@fieldwise_init
struct Until(MutableBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=ControlFlow[String,Int]
    var calls:Int
    def call_mut(mut self,var a:Int,var b:Int)->Self.Out:
        self.calls+=1
        if self.calls==2: return Self.Out(Break(String(a+b)))
        return Self.Out(Continue(a+b))
@fieldwise_init
struct Failure(MutableBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Error=Int
    var calls:Int
    def call_mut(mut self,var a:Int,var b:Int) raises Int -> Int:
        self.calls+=1
        raise a+b+self.calls

def main() raises:
    assert_equal(fold_left([1,2],0,Add(0)),6)
    assert_equal(iterated([1,2]).fold_left(Add(0),0),6)
    assert_equal(iterated([1,2]).reduce(Add(0),initial=0),6)
    assert_equal(iterated([1,2]).reduce(Add(0)),4)
    assert_equal(Bool(iterated(List[Int]()).reduce_optional(Add(0))),False)
    var early=iterated([1,2,3]).fold_until(Until(0),0)
    assert_equal(early^.unwrap[Break[String]]().into_payload(),"3")
    assert_equal(reduce([1,2],Add(0),initial=0),6)
    assert_equal(reduce([1,2],Add(0)),4)
    var optional=reduce_optional([1,2],Add(0))
    assert_equal(optional.take(),4)
    assert_equal(Bool(reduce_optional(List[Int](),Add(0))),False)
    var end=fold_until([1,2,3],0,Until(0))
    assert_equal(end^.unwrap[Break[String]]().into_payload(),"3")
    try: _=fold_left([1],0,Failure(0))
    except error:
        comptime assert type_of(error)==Int
        assert_equal(error,2)
    try: _=reduce([1,2],Failure(0))
    except error:
        assert_equal(error^.unwrap[ReductionStepError[Int]]().error,4)
