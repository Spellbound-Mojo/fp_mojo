"""Native generic traversal keeps raised errors and external origins exact."""
from fp.functions import piped
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ListFamily
from fp.data import Result, Ok
from std.testing import assert_equal


def tg_tap[P: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //,
           F: def(P) raises E -> Optional[R]](ref function: F, var values: List[P]) raises E -> Optional[List[P]]:
    return piped(values^).traverse_tap[OptionalFamily, ListFamily, E=E, X=E](function).get()


def tg_void[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A) raises E -> Optional[R]](ref function: F, var values: List[A]) raises E -> Optional[NoneType]:
    return iterated(values^).traverse_void[OptionalFamily, E=E, X=E](function)


def tg_result_void[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                   S: Movable & Deinitable, //, F: def(var A) raises E -> R](
    ref function: F, var value: Result[A, S]
) raises E -> Optional[Result[NoneType, S]] where OptionalFamily.CarrierCompatible[R]:
    return piped(value^).traverse_void[G=OptionalFamily, A=A, R=R, Failure=S, E=E, X=E](function).get()


@fieldwise_init
struct TGFailure(Movable):
    var code: Int


def tg_checked(value: Int) raises TGFailure -> Optional[Int]:
    if value < 0: raise TGFailure(value)
    return Optional(value * 10)


def tg_views(anchor: List[Int]) raises:
    comptime View = Span[Int, origin_of(anchor)]
    def tg_measure(value: View) raises TGFailure -> Optional[Int]: return Optional(len(value))
    var values = List[View]()
    values.append(Span(anchor))
    var retained: Optional[List[View]]
    try: retained = tg_tap(tg_measure, values^)
    except: raise Error("unexpected callback error")
    assert_equal(retained.take()[0][1], 12)


def main() raises:
    var values: List[Int] = [1, 2]
    var kept: Optional[List[Int]]
    var done: Optional[NoneType]
    var inputs: List[Int] = [1, 2]
    var discarded: Optional[Result[NoneType, String]]
    try:
        kept = tg_tap(tg_checked, values^)
        done = tg_void(tg_checked, inputs^)
        discarded = tg_result_void(tg_checked, Result[Int, String](Ok(3)))
    except: raise Error("unexpected callback error")
    assert_equal(kept.take(), [1, 2])
    assert_equal(Bool(done), True)
    assert_equal(discarded.take().is_ok(), True)
    var failed = False
    var bad: List[Int] = [-1]
    try: _ = tg_tap(tg_checked, bad^)
    except error:
        comptime assert type_of(error) == TGFailure
        assert_equal(error.code, -1)
        failed = True
    assert_equal(failed, True)
    tg_views([11, 12])
