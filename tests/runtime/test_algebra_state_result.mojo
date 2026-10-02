"""Stack order determines where state survives a stored Result failure."""
from algebra_support.state_result import Base, Stack, Endpoint, Step, step, Next, assert_output
from fp.algebra import flat_map
from fp.effects import run
from fp._internal.errors import _propagate_error
from std.memory import ArcPointer
from std.builtin.rebind import rebind_var
from std.testing import assert_equal


def check[retain:Bool]() raises:
    comptime I=Stack[retain]
    comptime C=I.Bound[Endpoint[retain],Next[retain]]
    for source_failure in range(3):
        for next_failure in range(4):
            var trace=ArcPointer(List[Int]())
            var computation:C
            try:
                computation=flat_map[I](Next[retain](trace,next_failure),step[retain](trace,1,5,source_failure))
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
                assert_equal(String(rebind_var[Error](error^)),"native action failure" if source_failure==2 or next_failure==2 else "native callback failure")
            assert_equal(caught,source_failure==2 or (source_failure==0 and next_failure>=2))
            if output:
                assert_output[retain](output.take(),30,15 if source_failure==1 else 30,1 if source_failure==1 else 3 if next_failure==1 else 0)
            assert_equal(len(trace[]),1 if source_failure!=0 else 2 if next_failure==3 else 3)
            assert_equal(trace[][0],1)
            if len(trace[])>=2:
                assert_equal(trace[][1],2)
            if len(trace[])==3:
                assert_equal(trace[][2],3)


def main() raises:
    check[True]()
    check[False]()
    print("State/Result: state order, short circuit, deferred callbacks, native failures")
