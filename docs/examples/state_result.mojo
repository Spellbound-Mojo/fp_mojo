"""Transformer order decides whether a stored failure returns the updated state."""
from fp.algebra import pure, flat_map
from fp.effects import State, StateT, ResultT, run, lift, put
from fp.algebra import ResultFamily
from fp.data import Result, Err
from std.testing import assert_equal

comptime DomainResult=Result[Int,String]
comptime Keep=ResultT[State[Int],String]
comptime Discard=StateT[ResultFamily[String],Int]

def failure()->DomainResult:
    return Err(String("rejected"))

# Each adapter places the same domain failure at its stack's base boundary.
def fail_keep(var unused:NoneType)->type_of(pure[State[Int]](failure())):
    return pure[State[Int]](failure())

def fail_discard(var unused:NoneType)->type_of(lift[Discard](failure())):
    return lift[Discard](failure())

def main() raises:
    var kept=run[State[Int]](flat_map[Keep](fail_keep,lift[Keep](put[State[Int]](15))),10)
    comptime assert type_of(kept)==Tuple[DomainResult,Int]
    ref result=kept[0]
    var state=kept[1]
    assert_equal(result.is_err(),True)
    assert_equal(state,15)
    print("ResultT[State]: failed, returned state =",state)

    var discarded=run[Discard](flat_map[Discard](fail_discard,put[Discard](15)),10)
    comptime assert type_of(discarded)==Result[Tuple[Int,Int],String]
    assert_equal(discarded.is_err(),True)
    print("StateT[Result]: failed, no state payload")
