from fp.algebra import traverse, OptionalFamily, ResultFamily, ListFamily, IdentityFamily
from fp.callables import as_unary
from fp.data import Result, Ok, Err
from std.iter import Iterator
from std.testing import assert_equal, assert_true
from algebra_support import ints

from algebra_support.iterators import Counted


def option(var value:Int)->Optional[Int]:
    if value == 3:
        return Optional[Int]()
    return Optional(value+1)


def result(var value:Int)->Result[Int,Int]:
    if value == 3:
        return Result[Int,Int](Err(37))
    return Result[Int,Int](Ok(value+1))


def alternatives(var value:Int)->List[Int]:
    return [value,value+10]


def main() raises:
    var pulls=0
    var absent=traverse[ListFamily,OptionalFamily](as_unary(option),Counted(Pointer(to=pulls),0,8))
    assert_true(not absent)
    assert_equal(pulls,3)
    pulls=0
    var failed=traverse[ListFamily,ResultFamily[Int]](as_unary(result),Counted(Pointer(to=pulls),0,8))
    assert_true(failed.is_err())
    assert_equal(pulls,3)
    pulls=0
    var present=traverse[ListFamily,OptionalFamily](as_unary(option),Counted(Pointer(to=pulls),0,2))
    assert_equal(present.value(),ints(2,3))
    assert_equal(pulls,3)
    var choices=traverse[ListFamily,ListFamily](as_unary(alternatives),ints(1,2))
    assert_equal(len(choices),4)
    assert_equal(choices[0],ints(1,2))
    assert_equal(choices[1],ints(1,12))
    assert_equal(choices[2],ints(11,2))
    assert_equal(choices[3],ints(11,12))
    print("algebra traversal: source pulls, short circuit, Cartesian shape")
