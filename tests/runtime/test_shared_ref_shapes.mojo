"""One shared reference preserves every call shape and distinct native errors."""
from fp.callables import CallContract,Unary,Binary,Thunk,BorrowCallable,shared_ref,SharedRef,call_once,invoke_borrowed_once
from std.testing import assert_equal

@fieldwise_init
struct Many(CallContract,Unary,Binary,Thunk,BorrowCallable):
    comptime Out=Int
    comptime Error=Int
    comptime Arg=Int
    comptime First=Int
    comptime Second=Int
    comptime Payload=String
    comptime Result=Bool
    comptime Failure=String
    var offset:Int
    def call(self) raises Int -> Int:
        if self.offset<0:raise self.offset
        return self.offset
    def call(self,var value:Int) raises Int -> Int:return self.call()+value
    def call(self,var first:Int,var second:Int) raises Int -> Int:return self.call()+first+second
    def invoke(self,ref value:String) raises String -> Bool:
        if not value:raise String("empty")
        return value.byte_length()==self.offset

def main() raises:
    var function=Many(4)
    var reference=shared_ref(function)
    var n:Int
    var a:Int
    var b:Int
    try:
        n=call_once(reference)
        a=call_once(reference,3)
        b=call_once(reference,3,5)
    except:raise Error("unexpected numeric failure")
    assert_equal(n,4)
    assert_equal(a,7)
    assert_equal(b,12)
    var good:Bool
    try:good=invoke_borrowed_once[String](String("four"),reference)
    except:raise Error("unexpected borrowed failure")
    assert_equal(good,True)
    var caught=String()
    try:_=invoke_borrowed_once[String](String(),reference)
    except error:
        comptime assert type_of(error)==String
        caught=error^
    assert_equal(caught,"empty")
    _=reference^
    function.offset = -7
    var code=0
    try:_=call_once(shared_ref(function))
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,-7)
    assert_equal(function.offset,-7)
