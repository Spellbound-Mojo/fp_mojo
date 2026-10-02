"""Lazy State/Result application preserves sequencing and skips right owners."""
from algebra_support.state_result import Base, Stack, Step, Endpoint, step, Produce, Combine, assert_output
from fp.algebra import map2_lazy
from fp.effects import run
from fp._internal.errors import _propagate_error
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.testing import assert_equal

def check[retain:Bool]() raises:
    comptime I=Stack[retain]
    comptime C=I.Combined[Endpoint[retain],Combine,Produce[retain]]
    for left_failure in range(3):
        for right_failure in range(4):
            for combine_failure in [False,True]:
                var trace=ArcPointer(List[Int]())
                var computation:C
                try:
                    computation=map2_lazy[I](Combine(trace,combine_failure),step[retain](trace,1,5,left_failure),Produce[retain](trace,right_failure))
                except error:
                    comptime assert type_of(error)==Never
                    _propagate_error[Never](error^)
                assert_equal(len(trace[]),0)
                var caught=False
                var output=Optional[Step[retain].Output]()
                try:
                    var value=run[Base[retain]](computation^,10)
                    comptime assert type_of(value)==Step[retain].Output
                    output=Optional(rebind_var[Step[retain].Output](value^))
                except error:
                    comptime assert type_of(error)==Error
                    caught=True
                    var message=String(rebind_var[Error](error^))
                    assert_equal(message,"native action failure" if left_failure==2 or right_failure==2 else "native factory failure" if right_failure==3 else "native combination failure")
                assert_equal(caught,left_failure==2 or (left_failure==0 and (right_failure>=2 or (right_failure==0 and combine_failure))))
                if output:
                    assert_output[retain](output.take(),37,15 if left_failure==1 else 22,1 if left_failure==1 else 3 if right_failure==1 else 0)
                var calls=1 if left_failure!=0 else 2 if right_failure==3 else 3 if right_failure!=0 else 4
                assert_equal(len(trace[]),calls)
                for i in range(calls):
                    assert_equal(trace[][i],i+1)

def main() raises:
    check[True]()
    check[False]()
    print("State/Result: lazy application, skipped factories, state sequencing, exact failures")
