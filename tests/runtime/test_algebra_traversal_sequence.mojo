"""Sequence uses traversal's deferred and Applicative-only paths."""
from fp.algebra import sequence, ListFamily
from fp.effects import Reader, State, action, run
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from algebra_support.arrows import ReadStep, StateStep
from algebra_support.applicative_traversal import ResultApplicative
from algebra_support import ints

def main() raises:
    var readers=[action[Reader[Int],Int](ReadStep(1)),action[Reader[Int],Int](ReadStep(2))]
    var environment=10
    assert_equal(run[Reader[Int]](sequence[ListFamily,Reader[Int]](readers^),environment),ints(11,12))
    var states=[action[State[Int],Int](StateStep(1)),action[State[Int],Int](StateStep(2))]
    var output=run[State[Int]](sequence[ListFamily,State[Int]](states^),10)
    assert_equal(output[0],ints(11,13))
    assert_equal(output[1],13)
    var results=[Result[Int,Int](Ok(2)),Result[Int,Int](Err(37)),Result[Int,Int](Ok(4))]
    var failed=sequence[ListFamily,ResultApplicative](results^)
    assert_equal(failed.is_err(),True)
    var code=0
    try:
        _=failed^.raise_on_err()
    except stored:
        code=stored
    assert_equal(code,37)
    print("sequence: Reader, State and Applicative-only Result")
