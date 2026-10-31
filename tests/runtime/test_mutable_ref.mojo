"""One inferred reference preserves every callable shape and exact error channel."""
from fp.callables import mut_ref
from fp.callables import MutableUnary,MutableBinary,MutableThunk,BorrowMutableCallable,call_once,invoke_borrowed_once
from fp.iteration import iterated
from fp.functions import pipeline
from std.testing import assert_equal
@fieldwise_init
struct Unary(MutableUnary):
    comptime Arg=Int
    comptime Out=Int
    var calls:Int
    def call_mut(mut self,var value:Int)->Int:
        self.calls+=1
        return value+self.calls
@fieldwise_init
struct Binary(MutableBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    var calls:Int
    def call_mut(mut self,var first:Int,var second:Int)->Int:
        self.calls+=1
        return first+second+self.calls
@fieldwise_init
struct Thunk(MutableThunk):
    comptime Out=Int
    var calls:Int
    def call_mut(mut self)->Int:
        self.calls+=1
        return self.calls
@fieldwise_init
struct Predicate(BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    var calls:Int
    def invoke_mut(mut self,ref value:Int)->Bool:
        self.calls+=1
        return self.calls%2==0
@fieldwise_init
struct Dual(MutableUnary,BorrowMutableCallable):
    comptime Arg=Int
    comptime Out=Int
    comptime Payload=Int
    comptime Result=Bool
    var calls:Int
    def call_mut(mut self,var value:Int)->Int:
        self.calls+=1
        return value+self.calls
    def invoke_mut(mut self,ref value:Int)->Bool:
        self.calls+=1
        return self.calls%2==0

def shapes() raises:
    var unary=Unary(0)
    assert_equal(iterated(range(3)).map(mut_ref(unary)).to_list(),[1,3,5])
    assert_equal(unary.calls,3)
    assert_equal(pipeline[List[Int]]([0,1]).map(mut_ref(unary)).get(),[4,6])
    assert_equal(unary.calls,5)
    var binary=Binary(0)
    assert_equal(iterated(range(3)).fold_left(mut_ref(binary),0),9)
    assert_equal(binary.calls,3)
    var thunk=Thunk(0)
    assert_equal(call_once(mut_ref(thunk)),1)
    assert_equal(call_once(mut_ref(thunk)),2)
    assert_equal(thunk.calls,2)
    var predicate=Predicate(0)
    assert_equal(iterated(range(4)).filter(mut_ref(predicate)).to_list(),[1,3])
    assert_equal(predicate.calls,4)
    var dual=Dual(0)
    assert_equal(iterated(range(3)).map(mut_ref(dual)).to_list(),[1,3,5])
    assert_equal(iterated(range(3)).filter(mut_ref(dual)).to_list(),[0,2])
    assert_equal(dual.calls,6)

@fieldwise_init
struct TwoErrors(MutableUnary,BorrowMutableCallable):
    comptime Arg=Int
    comptime Out=Int
    comptime Error=Int
    comptime Payload=String
    comptime Result=Bool
    comptime Failure=String
    var calls:Int
    def call_mut(mut self,var value:Int) raises Int -> Int:
        self.calls+=1
        raise value
    def invoke_mut(mut self,ref value:String) raises String -> Bool:
        self.calls+=1
        raise value.copy()
def distinct_errors() raises:
    var callback=TwoErrors(0)
    var code=0
    try:_=call_once(mut_ref(callback),7)
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,7)
    var message=String('kept')
    var caught=String()
    try:_=invoke_borrowed_once[String](message,mut_ref(callback))
    except error:
        comptime assert type_of(error)==String
        caught=error^
    assert_equal(caught,'kept')
    assert_equal(callback.calls,2)


def main() raises:
    shapes()
    distinct_errors()
