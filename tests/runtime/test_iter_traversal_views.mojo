"""Traversal terminals reuse callable views and honor their declared family."""
from fp.functions import kleisli, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily, ListFamily
from fp.data import Result, Ok, Err
from algebra_support.external import PublicMonad
from algebra_support.iterators import Counted
from std.testing import assert_equal, assert_true


def twice(var value: Int) -> Optional[Int]: return Optional(value * 2)
def increment(var value: Int) -> Int: return value + 1
def choices(var value: Int) -> List[Int]: return [value, value + 10]
def reject(var value: Int) -> Result[Int, String]:
    if value == 2: return Err(String("stop"))
    return Ok(value)


def main() raises:
    var chain = kleisli[OptionalFamily](twice)
    assert_equal(iterated(range(3)).traverse(chain).value(), [0, 2, 4])
    assert_equal(iterated(range(0)).traverse(chain).value(), List[Int]())
    assert_true(Bool(iterated(range(3)).traverse_void(chain)))
    assert_true(Bool(iterated(range(0)).traverse_void(chain)))
    assert_equal(chain.call(4).value(), 8)
    assert_equal(iterated(range(2)).traverse[OptionalFamily](chain).value(), [0, 2])
    assert_true(Bool(iterated(range(2)).traverse_void[OptionalFamily, X=Error](chain)))
    var composed = flow(increment, twice)
    assert_equal(iterated(range(3)).traverse(composed).value(), [2, 4, 6])
    assert_true(Bool(iterated(range(3)).traverse_void(composed)))
    assert_equal(composed.call(4).value(), 10)

    var pulls = 0
    var stopping = kleisli[ResultFamily[String]](reject)
    var failed = iterated(Counted(Pointer(to=pulls), 0, 5)).traverse(stopping)
    assert_equal(pulls, 2)
    assert_equal(failed^.swap().to_optional().value(), "stop")
    pulls = 0
    var discarded = iterated(Counted(Pointer(to=pulls), 0, 5)).traverse_void(stopping)
    assert_equal(pulls, 2)
    assert_equal(discarded^.swap().to_optional().value(), "stop")
    assert_true(stopping.call(3).is_ok())

    var branching = kleisli[ListFamily](choices)
    assert_equal(iterated(range(2)).traverse(branching), [[0, 1], [0, 11], [10, 1], [10, 11]])
    assert_equal(len(iterated(range(2)).traverse_void(branching)), 4)
    assert_equal(len(iterated(range(0)).traverse_void(branching)), 1)

    # Same Optional storage, distinct sequencing policy and native error.
    var declared = kleisli[PublicMonad[OptionalFamily, 3]](twice)
    var caught = 0
    try: _ = iterated(range(1)).traverse(declared)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught, 704)
    caught = 0
    try: _ = iterated(range(1)).traverse_void(declared)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught, 704)
    # Explicit selection continues to override inference.
    assert_equal(iterated(range(2)).traverse[OptionalFamily](declared).value(), [0, 2])
    assert_true(Bool(iterated(range(2)).traverse_void[OptionalFamily](declared)))
