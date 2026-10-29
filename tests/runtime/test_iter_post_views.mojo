"""Iterator postprocessing borrows reusable chains and preserves selected policy."""
from fp.functions import kleisli, pipeline, flow
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok, Err
from algebra_support.external import PublicMonad
from algebra_support.iterators import Counted
from std.testing import assert_equal, assert_true

def expand(var value: Int) -> Optional[List[Int]]: return Optional(List[Int]([value,value*10]))
def select(var value: Int) -> Optional[Optional[Int]]: return Optional(Optional(value) if value % 2 == 0 else Optional[Int]())
def increment(var value: Int) -> Int: return value+1
def reject(var value: Int) -> Result[Optional[Int],String]:
    if value == 2: return Err(String("stop"))
    return Ok(Optional(value))
def reject_flat(var value: Int) -> Result[List[Int],String]:
    if value == 2: return Err(String("stop"))
    return Ok(List[Int]([value]))

def main() raises:
    var chain = kleisli[OptionalFamily](expand)
    assert_equal(iterated(range(1,3)).flat_traverse(chain).value(),[1,10,2,20])
    assert_equal(iterated(range(0)).flat_traverse(chain).value(),List[Int]())
    assert_equal(chain.call(4).value(),[4,40])
    var selector = kleisli[OptionalFamily](select)
    assert_equal(iterated(range(4)).traverse_filter(selector).value(),[0,2])
    assert_equal(iterated(range(0)).traverse_filter(selector).value(),List[Int]())
    assert_equal(selector.call(6).value().value(),6)
    assert_equal(iterated(range(1)).flat_traverse[OptionalFamily,X=Error](chain).value(),[0,0])
    assert_equal(iterated(range(1)).traverse_filter[OptionalFamily,X=Error](selector).value(),[0])
    var composed = flow(increment,expand)
    assert_equal(iterated(range(2)).flat_traverse(composed).value(),[1,10,2,20])
    var composed_select = flow(increment,select)
    assert_equal(iterated(range(3)).traverse_filter(composed_select).value(),[2])
    var pulls = 0
    var stopping = kleisli[ResultFamily[String]](reject)
    var failed = iterated(Counted(Pointer(to=pulls),0,5)).traverse_filter(stopping)
    assert_equal(pulls,2)
    assert_equal(failed^.swap().to_optional().value(),"stop")
    pulls = 0
    var stopping_flat = kleisli[ResultFamily[String]](reject_flat)
    var failed_flat = iterated(Counted(Pointer(to=pulls),0,5)).flat_traverse(stopping_flat)
    assert_equal(pulls,2)
    assert_equal(failed_flat^.swap().to_optional().value(),"stop")
    assert_true(stopping.call(3).is_ok())
    assert_true(stopping_flat.call(3).is_ok())
    # An Optional carrier alone cannot identify this custom map policy.
    var declared = kleisli[PublicMonad[OptionalFamily,1]](expand)
    var declared_select = kleisli[PublicMonad[OptionalFamily,1]](select)
    var caught = 0
    try: _ = iterated(range(1)).flat_traverse(declared)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,702)
    caught = 0
    try: _ = iterated(range(1)).traverse_filter(declared_select)
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,702)
    caught = 0
    try: _ = pipeline(List[Int]([1])).flat_traverse(declared).get()
    except error:
        comptime assert type_of(error) == Int
        caught = error
    assert_equal(caught,702)
