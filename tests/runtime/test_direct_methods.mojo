"""Instance dictionaries and library callables are ordinary structs: generic
code may call their static and receiver methods directly, with the same
results as the public entries."""
from fp.algebra import IdentityFamily, OptionalFamily, ResultFamily, ListFamily, StringMonoid, ListMonoid
from fp.callables import as_unary
from fp.functions import flow, partial, Identity
from fp.data import Result, Ok
from fp.effects import Reader, State, Writer, action, run, run_writer, writer
from std.testing import assert_equal

from algebra_support import ints as L, increment as inc, Add, Next
from algebra_support.arrows import ReadStep, StateStep


comptime R = Reader[Int]
comptime S = State[Int]
comptime W = Writer[StringMonoid]


def some(var value: Int) -> Optional[Int]:
    return Optional(value)


def ok(var value: Int) -> Result[Int, Error]:
    return Result[Int, Error](Ok(value + 3))


def many(var value: Int) -> List[Int]:
    return [value, value + 4]


def read_step(var value: Int) -> type_of(action[R, Int](ReadStep(0))):
    return action[R, Int](ReadStep(value))


def state_step(var value: Int) -> type_of(action[S, Int](StateStep(0))):
    return action[S, Int](StateStep(value))


def logged(var value: Int) -> type_of(writer[W, Int](Tuple(String(), Int()))):
    return writer[W, Int](Tuple(String("b"), value + 2))


def eager() raises:
    assert_equal(IdentityFamily.map(as_unary(inc), 1), 2)
    assert_equal(IdentityFamily.pure(3), 3)
    assert_equal(IdentityFamily.map2_lazy(Add(), 1, Next(2)), 3)
    assert_equal(IdentityFamily.flat_map(as_unary(inc), 4), 5)
    assert_equal(IdentityFamily.traverse[OptionalFamily](as_unary(some), 6).value(), 6)

    assert_equal(OptionalFamily.map(as_unary(inc), Optional(1)).value(), 2)
    assert_equal(OptionalFamily.pure(3).value(), 3)
    assert_equal(OptionalFamily.map2_lazy(Add(), Optional(1), Next(Optional(2))).value(), 3)
    assert_equal(OptionalFamily.flat_map(as_unary(some), Optional(4)).value(), 4)
    assert_equal(OptionalFamily.traverse[IdentityFamily](as_unary(inc), Optional(5)).value(), 6)
    assert_equal(OptionalFamily.lift(7).value(), 7)

    comptime E = ResultFamily[Error]
    assert_equal(E.map(as_unary(inc), Result[Int, Error](Ok(1))).raise_on_err(), 2)
    assert_equal(E.pure(3).raise_on_err(), 3)
    assert_equal(E.map2_lazy(Add(), Result[Int, Error](Ok(1)), Next(Result[Int, Error](Ok(2)))).raise_on_err(), 3)
    assert_equal(E.flat_map(as_unary(ok), Result[Int, Error](Ok(1))).raise_on_err(), 4)
    var traversed = E.traverse[OptionalFamily](as_unary(some), Result[Int, Error](Ok(5)))
    assert_equal(traversed.take().raise_on_err(), 5)
    assert_equal(E.lift(6).raise_on_err(), 6)

    assert_equal(ListFamily.map(as_unary(inc), L(1, 2)), L(2, 3))
    assert_equal(ListFamily.pure(1), L(1))
    assert_equal(ListFamily.map2_lazy(Add(), L(1, 2), Next(L(3, 4))), L(4, 5, 5, 6))
    assert_equal(ListFamily.flat_map(as_unary(many), L(1, 2)), L(1, 5, 2, 6))
    assert_equal(ListFamily.traverse[OptionalFamily](as_unary(some), L(1, 2)).value(), L(1, 2))

    assert_equal(StringMonoid.combine(StringMonoid.empty(), String("ab")), "ab")
    assert_equal(ListMonoid[Int].combine(ListMonoid[Int].empty(), L(1, 2)), L(1, 2))


def deferred() raises:
    var environment = 10
    assert_equal(run[R](R.map(as_unary(inc), R.pure(1)), environment), 2)
    assert_equal(run[R](R.flat_map(as_unary(read_step), R.pure(1)), environment), 11)
    assert_equal(run[R](R.map2_lazy(Add(), R.pure(1), Next(R.pure(2))), environment), 3)
    assert_equal(run[R](R.lift(5), environment), 5)
    assert_equal(run[R](R.endpoint[Int](ReadStep(3)), environment), 13)

    var mapped = run[S](S.map(as_unary(inc), S.pure(1)), 7)
    assert_equal(mapped[0], 2)
    assert_equal(mapped[1], 7)
    var bound = run[S](S.flat_map(as_unary(state_step), S.pure(2)), 7)
    assert_equal(bound[0], 9)
    assert_equal(bound[1], 9)
    var combined = run[S](S.map2_lazy(Add(), S.pure(1), Next(S.pure(2))), 7)
    assert_equal(combined[0], 3)
    var lifted = run[S](S.lift(4), 7)
    assert_equal(lifted[0], 4)
    assert_equal(lifted[1], 7)
    var ended = run[S](S.endpoint[Int](StateStep(1)), 7)
    assert_equal(ended[0], 8)

    var written = run_writer[W](W.map(as_unary(inc), writer[W, Int](Tuple(String("a"), 1))))
    assert_equal(written[0], "a")
    assert_equal(written[1], 2)
    var empty = run_writer[W](W.pure(3))
    assert_equal(empty[0], "")
    assert_equal(empty[1], 3)
    var chained = run_writer[W](W.flat_map(as_unary(logged), writer[W, Int](Tuple(String("a"), 1))))
    assert_equal(chained[0], "ab")
    assert_equal(chained[1], 3)
    var paired = run_writer[W](W.map2_lazy(Add(), writer[W, Int](Tuple(String("a"), 1)),
                                           Next(writer[W, Int](Tuple(String("c"), 2)))))
    assert_equal(paired[0], "ac")
    assert_equal(paired[1], 3)
    var raised = run_writer[W](W.lift(4))
    assert_equal(raised[0], "")
    assert_equal(raised[1], 4)


def product(a: Int, b: Int) -> Int:
    return a * b


def plus(a: Int, b: Int) -> Int:
    return a + b


def seven() -> Int:
    return 7


def compositions() raises:
    # A composition of shared stages offers every receiver mode of its arity.
    var scale = flow(partial(product, 3), Identity[Int]())
    assert_equal(scale.call(1), 3)
    assert_equal(scale.call_mut(2), 6)
    assert_equal(scale^.call_once(3), 9)
    var add = flow(partial(plus), Identity[Int]())
    assert_equal(add.call(1, 2), 3)
    assert_equal(add.call_mut(2, 3), 5)
    assert_equal(add^.call_once(3, 4), 7)
    var constant = flow(partial(seven), Identity[Int]())
    assert_equal(constant.call(), 7)
    assert_equal(constant.call_mut(), 7)
    assert_equal(constant^.call_once(), 7)


def main() raises:
    eager()
    deferred()
    compositions()
    print("direct methods: native instances, transformer dictionaries, monoids and compositions")
