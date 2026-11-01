"""First-error accumulation preserves branch choice, liveness and owned cleanup."""
from fp.algebra.protocols import _Accumulate
from fp.algebra._result_accumulation import _ResultAccumulator,_FirstError
from fp.effects.layers import _ResultAcc
from fp.data import Result,Ok,Err
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Trace:
    var live:Int
    var combine:Int
    var drops:SIMD[DType.int64,2]

@fieldwise_init
struct Owner(Movable):
    var value:Int
    var id:Int
    var trace:ArcPointer[Trace]
    def __deinit__(deinit self):self.trace[].drops[self.id]+=1

struct Accumulate(_Accumulate):
    comptime Acc=Owner
    comptime Item=Owner
    comptime Error=Int
    @staticmethod
    def start() raises Int ->Self.Acc:raise 31
    @staticmethod
    def live(ref acc:Self.Acc)->Bool:
        acc.trace[].live+=1
        return acc.value<5
    @staticmethod
    def combine(var acc:Self.Acc,var item:Self.Item) raises Int ->Self.Acc:
        acc.trace[].combine+=1
        if item.value==99:raise 99
        acc.value+=item.value
        return acc^

def main() raises:
    comptime K=_ResultAcc[Accumulate,Owner]
    comptime assert K==_ResultAccumulator[Accumulate,_FirstError[Owner]]
    comptime assert K.Error==Int
    var start_code=0
    try:_=K.start()
    except error:
        comptime assert type_of(error)==Int
        start_code=error
    assert_equal(start_code,31)
    for left_error in [False,True]:
        for right_error in [False,True]:
            for left_value in [1,7]:
                for right_value in [2,99]:
                    var trace=ArcPointer(Trace(0,0,SIMD[DType.int64,2](0)))
                    var left=Result[Owner,Owner](Err(Owner(left_value,0,trace))) if left_error else Result[Owner,Owner](Ok(Owner(left_value,0,trace)))
                    var right=Result[Owner,Owner](Err(Owner(right_value,1,trace))) if right_error else Result[Owner,Owner](Ok(Owner(right_value,1,trace)))
                    var output=Optional[Result[Owner,Owner]]()
                    var code=0
                    try:output=Optional(K.combine(left^,right^))
                    except error:
                        comptime assert type_of(error)==Int
                        code=error
                    var called=not left_error and left_value<5 and not right_error
                    assert_equal(code,99 if called and right_value==99 else 0)
                    assert_equal(trace[].live,Int(not left_error))
                    assert_equal(trace[].combine,Int(called))
                    if output:
                        var result=output.take()
                        var stored_error=left_error or (left_value<5 and right_error)
                        assert_equal(result.is_err(),stored_error)
                        var actual:Int
                        if result.is_err():actual=result._err().value.value
                        else:actual=result._ok().value.value
                        var expected=left_value if left_error or left_value>=5 else right_value if right_error else left_value+right_value
                        assert_equal(actual,expected)
                        _=result^
                    assert_equal(trace[].drops[0],1)
                    assert_equal(trace[].drops[1],1)
