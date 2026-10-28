"""Generic shared wrappers forward their original exact result and error types."""
from fp.callables import Thunk,Unary,Binary,BorrowCallable,shared_ref,call_once,invoke_borrowed_once
from fp.data import Result,attempt_once
from test_shared_ref_shapes import Many
from std.testing import assert_equal

def capture[F:Thunk](factory:F)->Result[F.Out,F.Error]:
    return attempt_once(shared_ref(factory))

def invoke[F:Unary](function:F,var value:F.Arg) raises F.Error -> F.Out:
    return call_once(shared_ref(function),value^)

def invoke_pair[F:Binary](function:F,var first:F.First,var second:F.Second) raises F.Error -> F.Out:
    return call_once(shared_ref(function),first^,second^)

def read[F:BorrowCallable](function:F,ref value:F.Payload) raises F.Failure -> F.Result:
    return invoke_borrowed_once[F.Failure](value,shared_ref(function))

def main() raises:
    var function=Many(4)
    assert_equal(capture(function).get_or(0),4)
    var result:Int
    try:result=invoke(function,3)+invoke_pair(function,3,5)
    except:raise Error("unexpected generic failure")
    assert_equal(result,19)
    var output:Bool
    try:output=read(function,String("four"))
    except:raise Error("unexpected borrowed generic failure")
    assert_equal(output,True)
