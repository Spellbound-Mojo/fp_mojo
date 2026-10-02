"""Mixed sums preserve earlier Writer and State effects on either failure."""
from algebra_support.nested import Base, Logged, Stack, Next, Endpoint, Emit, endpoint, finish, assert_payload
from fp.algebra import flat_map
from fp.effects import Reader, State, run, run_writer
from fp._internal.errors import _propagate_error
from std.memory import ArcPointer
from std.builtin.rebind import rebind, rebind_var
from std.testing import assert_equal


def check[optional_first:Bool,stateful:Bool]() raises:
    for source_failure in [0,1,2,4]:
        for next_failure in range(5):
            var trace=ArcPointer(List[Int]())
            comptime C=Stack[optional_first,stateful].Bound[Endpoint[optional_first,stateful],Next[optional_first,stateful]]
            var value:C
            try:
                value=flat_map[Stack[optional_first,stateful]](Next[optional_first,stateful](trace,next_failure),endpoint[optional_first,stateful](trace,1,5,source_failure))
            except error:
                comptime assert type_of(error)==Never
                _propagate_error[Never](error^)
            assert_equal(len(trace[]),0)
            var caught=0
            var environment=10
            var result=Optional[Emit[optional_first,stateful].Output]()
            try:
                result=Optional(finish[optional_first,stateful](value^,environment))
            except error:
                comptime assert type_of(error)==Int
                caught=rebind[Int](error)
            if result:
                var output=result.take()
                var pair:Emit[optional_first,stateful].Pair
                comptime if stateful:
                    var fields=rebind_var[Tuple[Emit[optional_first,stateful].Pair,Int]](output^)
                    assert_equal(fields[1],15 if source_failure else 30)
                    pair=fields[0].copy()
                else:
                    pair=rebind_var[Emit[optional_first,stateful].Pair](output^)
                assert_equal(pair[0],"1" if source_failure else "13")
                assert_payload[optional_first](pair[1].copy(),30 if stateful else 25,source_failure if source_failure else next_failure)
            assert_equal(caught,704 if source_failure==4 or (source_failure==0 and next_failure==4) else 703 if source_failure==0 and next_failure==3 else 0)
            assert_equal(len(trace[]),1 if source_failure else 2 if next_failure==3 else 3)
            assert_equal(trace[][0],1)
            if len(trace[])>1:
                assert_equal(trace[][1],2)
            if len(trace[])>2:
                assert_equal(trace[][2],3)


def main() raises:
    check[True,False]()
    print("mixed Optional/Result over Writer/Reader: effects, short circuit, exact exceptions")
