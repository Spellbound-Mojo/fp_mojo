"""Generic callers preserve exact raised errors and argument-carried origins."""
from fp.functions import piped
from fp.iteration import iterated
from fp.combinators import fold_effect, any_effect, if_effect
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true


def efg_fold[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //,
             F: def(var A, var B) raises X -> R](ref function: F, var initial: A, var values: List[B]) raises X -> Optional[A] where R == Optional[A] and OptionalFamily.Element[R] == A:
    return piped(values^).fold_effect[G=OptionalFamily, A=A, B=B, R=R, X=X, Z=X](function,initial^).get()


def efg_any[P: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(P) raises E -> R](ref function: F, var values: List[P]) raises E -> Optional[Bool] where R == Optional[Bool] and OptionalFamily.Element[R] == Bool:
    return iterated(values^).any_effect[G=OptionalFamily, P=P, R=R, E=E, X=E](function)


def efg_choose[U: Movable & Deinitable, W: Movable & Deinitable, Y: Movable & Deinitable, //,
               L: def() raises Y -> U, R: def() -> W](ref on_true: L, ref on_false: R, var condition: Optional[Bool]) raises Y -> U where W == U and U == Optional[Int] and OptionalFamily.Element[U] == OptionalFamily.Element[W]:
    return if_effect[G=OptionalFamily, U=U, W=W, Y=Y, X=Y](on_true,on_false,condition^)


@fieldwise_init
struct EFGenericFailure(Movable):
    var code: Int


def efg_checked(a: Int,b: Int) raises EFGenericFailure -> Optional[Int]:
    if b<0: raise EFGenericFailure(b)
    return Optional(a+b)
def efg_checked_bool(x: Int) raises EFGenericFailure -> Optional[Bool]:
    if x<0: raise EFGenericFailure(x)
    return Optional(x>2)
def efg_left() raises EFGenericFailure -> Optional[Int]: return Optional(8)
def efg_right() -> Optional[Int]: return Optional(9)
def efg_raise() raises EFGenericFailure -> Optional[Int]: raise EFGenericFailure(71)


def efg_origins(anchor: List[Int]) raises:
    comptime View = Span[Int, origin_of(anchor)]
    def last(var first: View,var second: View) -> Optional[View]: return Optional(second)
    var values = List[View]()
    values.append(Span(anchor)); values.append(Span(anchor))
    var result = fold_effect[OptionalFamily](last,Span(anchor),values^)
    assert_equal(result.take()[1],12)
    def choose_view() {ref anchor} -> Result[View,String]: return Ok(Span(anchor))
    var chosen = piped(Result[Bool,String](Ok(True))).if_effect(choose_view,choose_view).get().raise_on_err()
    assert_equal(chosen[0],11)


def main() raises:
    var xs: List[Int] = [1,2,3]
    var total: Optional[Int]
    var found: Optional[Bool]
    var chosen: Optional[Int]
    try:
        total = efg_fold(efg_checked,4,xs.copy())
        found = efg_any(efg_checked_bool,xs.copy())
        chosen = efg_choose(efg_left,efg_right,Optional(True))
    except: raise Error("unexpected native error")
    assert_equal(total.take(),10)
    assert_true(found.take())
    assert_equal(chosen.take(),8)
    var failure = 0
    var bad: List[Int] = [1,-2,3]
    try: _ = efg_fold(efg_checked,0,bad^)
    except error:
        comptime assert type_of(error) == EFGenericFailure
        failure = error.code
    assert_equal(failure,-2)
    try: _ = efg_choose(efg_raise,efg_right,Optional(True))
    except error:
        comptime assert type_of(error) == EFGenericFailure
        failure = error.code
    assert_equal(failure,71)
    failure = 0
    try: _ = if_effect[OptionalFamily](efg_right,efg_raise,Optional(False))
    except error:
        comptime assert type_of(error) == EFGenericFailure
        failure = error.code
    assert_equal(failure,71)
    efg_origins([11,12])
