from fp.algebra import map, pure, flat_map, map2_lazy, map2, ap, flatten, sequence, empty, combine, StringMonoid, ListMonoid, IdentityFamily, OptionalFamily, ResultFamily, ListFamily
from fp.callables import OnceThunk, as_unary
from fp.data import Result, Ok, Err
from std.builtin.rebind import rebind_var
from std.testing import assert_equal, assert_true

from algebra_support import ints as L, increment as inc, Add, Next

def opt(var x: Int) -> Optional[Int]:
    return Optional(x+2)

def res(var x: Int) -> Result[Int,Error]:
    return Result[Int,Error](Ok(x+3))

def many(var x: Int) -> List[Int]:
    return [x, x+4]

def check_instances() raises:
    assert_equal(map[IdentityFamily](1, as_unary(inc)),2)
    assert_equal(map[OptionalFamily](Optional(1), as_unary(inc)).value(),2)
    assert_equal(map[ResultFamily[Error]](Result[Int,Error](Ok(1)), as_unary(inc)).raise_on_err(),2)
    assert_equal(map[ListFamily](L(1,2), as_unary(inc)), L(2,3))
    assert_equal(flat_map[OptionalFamily](Optional(1), as_unary(opt)).value(),3)
    assert_equal(flat_map[ResultFamily[Error]](Result[Int,Error](Ok(1)), as_unary(res)).raise_on_err(),4)
    assert_equal(flat_map[ListFamily](L(1,2), as_unary(many)), L(1,5,2,6))
    assert_equal(pure[IdentityFamily](1),1)
    assert_equal(pure[OptionalFamily](1).value(),1)
    assert_equal(pure[ResultFamily[Error]](1).raise_on_err(),1)
    assert_equal(pure[ListFamily](1), L(1))
    assert_equal(map2_lazy[IdentityFamily](1,Next(2),Add()),3)
    assert_equal(map2_lazy[OptionalFamily](Optional(1),Next(Optional(2)),Add()).value(),3)
    assert_equal(map2_lazy[ResultFamily[Error]](Result[Int,Error](Ok(1)),Next(Result[Int,Error](Ok(2))),Add()).raise_on_err(),3)
    assert_equal(map2_lazy[ListFamily](L(1,2),Next(L(3,4)),Add()), L(4,5,5,6))


@fieldwise_init
struct CountedFactory[T: Movable & Deinitable, origin: MutOrigin](OnceThunk):
    var value: Self.T
    var calls: Pointer[Int, origin=Self.origin]
    comptime Out = Self.T

    def call_once(deinit self) -> Self.T:
        self.calls[] += 1
        return self.value^


def check_lazy_factory() raises:
    var calls = 0
    var absent = map2_lazy[OptionalFamily](
        Optional[Int](), CountedFactory(Optional(2), Pointer(to=calls)), Add()
    )
    assert_true(not absent)
    assert_equal(calls, 0)
    var empty = map2_lazy[ListFamily](
        List[Int](), CountedFactory(L(3, 4), Pointer(to=calls)), Add()
    )
    assert_equal(len(empty), 0)
    assert_equal(calls, 0)
    var pairs = map2_lazy[ListFamily](
        L(1, 2), CountedFactory(L(3, 4), Pointer(to=calls)), Add()
    )
    assert_equal(pairs, L(4, 5, 5, 6))
    assert_equal(calls, 1)
    var failed = map2_lazy[ResultFamily[Int]](
        Result[Int, Int](Err(9)), CountedFactory(Result[Int, Int](Ok(2)), Pointer(to=calls)),
        Add())
    assert_true(failed.is_err())
    assert_equal(calls, 1)


def twice_inc(var value:Int)->Int:
    return inc(inc(value))

def opt_pure(var value:Int)->Optional[Int]:
    return Optional(value)

def nested_opt(var value:Int)->Optional[Int]:
    return flat_map[OptionalFamily](opt(value),as_unary(inc_optional))

def inc_optional(var value:Int)->Optional[Int]:
    return Optional(inc(value))

def check_derived_and_laws() raises:
    from fp.functions import Identity
    assert_equal(map2[OptionalFamily](Add(),Optional(1),Optional(2)).value(),3)
    assert_equal(ap[OptionalFamily](Optional(as_unary(inc)),Optional(3)).value(),4)
    assert_equal(flatten[OptionalFamily](Optional(Optional(3))).value(),3)
    var nested:List[List[Int]]=[L(1,2),L(3)]
    assert_equal(flatten[ListFamily](nested^),L(1,2,3))
    var options:List[Optional[Int]]=[Optional(1),Optional(2)]
    assert_equal(sequence[ListFamily,OptionalFamily](options^).value(),L(1,2))
    assert_equal(empty[StringMonoid](),String())
    assert_equal(combine[StringMonoid](String("a"),String("b")),String("ab"))
    assert_equal(combine[ListMonoid[Int]](L(1,2),L(3)),L(1,2,3))
    assert_equal(map[ListFamily](L(1,2,3),Identity[Int]()),L(1,2,3))
    assert_equal(map[ListFamily](map[ListFamily](L(1,2),as_unary(inc)),as_unary(inc)),map[ListFamily](L(1,2),as_unary(twice_inc)))
    for value in [-2,0,7]:
        assert_equal(flat_map[OptionalFamily](pure[OptionalFamily](value),as_unary(opt)).value(),opt(value).value())
        assert_equal(flat_map[OptionalFamily](Optional(value),as_unary(opt_pure)).value(),value)
        assert_equal(flat_map[OptionalFamily](flat_map[OptionalFamily](Optional(value),as_unary(opt)),as_unary(inc_optional)).value(),flat_map[OptionalFamily](Optional(value),as_unary(nested_opt)).value())


def main() raises:
    check_instances()
    check_lazy_factory()
    check_derived_and_laws()
    print("algebra: native instances, Cartesian order, lazy factory")
