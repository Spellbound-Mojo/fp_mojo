"""Flatten transfers each nested Result payload once and retains independent origins."""
from fp.data import Result,Ok,Err
from algebra_support.result_ownership import Token,trace
from std.testing import assert_equal

def owned[route:Int]() raises:
    var state=trace()
    comptime Inner=Result[Token,Token]
    comptime Outer=Result[Inner,Token]
    var nested:Outer
    comptime if route==0:
        nested=Ok(Inner(Ok(Token(1,state))))
    elif route==1:
        nested=Ok(Inner(Err(Token(2,state))))
    else:
        nested=Err(Token(3,state))
    var result=nested^.flatten()
    assert_equal(result.is_ok(),route==0)
    for i in range(1,4): assert_equal(state[].drops[i],0)
    _=result^
    for i in range(1,4): assert_equal(state[].drops[i],Int(i==route+1))

def views[route:Int](values:List[Int],errors:List[Int])->Result[Span[Int,origin_of(values)],Span[Int,origin_of(errors)]]:
    comptime Value=Span[Int,origin_of(values)]
    comptime Failure=Span[Int,origin_of(errors)]
    comptime Inner=Result[Value,Failure]
    comptime Outer=Result[Inner,Failure]
    comptime if route==0:
        return Outer(Ok(Inner(Ok(Span(values))))).flatten()
    elif route==1:
        return Outer(Ok(Inner(Err(Span(errors))))).flatten()
    else:
        return Outer(Err(Span(errors))).flatten()

def main() raises:
    var values:List[Int]=[7]
    var errors:List[Int]=[11]
    comptime for route in range(3):
        owned[route]()
        var result=views[route](values,errors)
        assert_equal(result.is_ok(),route==0)
        comptime if route==0:
            var view=result^.get_or(Span(values))
            assert_equal(Pointer(to=view[0])==Pointer(to=values[0]),True)
        else:
            var view=result^.swap().get_or(Span(errors))
            assert_equal(Pointer(to=view[0])==Pointer(to=errors[0]),True)
