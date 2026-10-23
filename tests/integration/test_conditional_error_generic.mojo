"""Generic selective recovery preserves borrowed origins and exact native errors."""
from fp.algebra import ResultFamily, fail
from fp.functions import piped
from fp.effects import ReaderT, run
from fp.data import Result, Ok
from std.testing import assert_equal
from std.builtin.rebind import rebind_var


def ceg_recover[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                C: def(A) raises E -> Bool, F: def(var A) raises E -> R](
    var source: Result[R, A], ref predicate: C, ref handler: F
) raises E -> Result[R, A]:
    return piped(source^).recover_if[ResultFamily[A], X=E, E=E, Z=E](predicate, handler).get()


def ceg_else[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
             C: def(A) raises E -> Bool, F: def(var A) raises E -> R](
    var source: R, ref predicate: C, ref handler: F
) raises E -> R where R == Result[ResultFamily[A].Element[R], A]:
    comptime assert R == Result[ResultFamily[A].Element[R], A]
    return rebind_var[R](piped(source^).or_else_if[ResultFamily[A], R=R, X=E, E=E, Z=E](predicate, handler).get())



def ceg_pure_predicate[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                       C: def(A) -> Bool, F: def(var A) raises E -> R](
    var source: Result[R, A], ref predicate: C, ref handler: F
) raises E -> Result[R, A]:
    return piped(source^).recover_if[ResultFamily[A], R=R, E=E, Z=E](predicate, handler).get()


def ceg_pure_handler[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                     C: def(A) raises E -> Bool, F: def(var A) -> R](
    var source: Result[R, A], ref predicate: C, ref handler: F
) raises E -> Result[R, A]:
    return piped(source^).recover_if[ResultFamily[A], R=R, X=E, Z=E](predicate, handler).get()


def ceg_origins(values: List[Int]) raises:
    var view = Span(values)
    comptime V = type_of(view)
    def accepts(error: V) raises V -> Bool: return error[0] > 0
    def pure_accepts(error: V) -> Bool: return True
    def pure_recover(var error: V) -> V: return error
    def no(error: V) raises V -> Bool: return False
    def recover(var error: V) raises V -> V: return error
    def replace(var error: V) raises V -> Result[V, V]: return Ok(error)
    assert_equal(ceg_recover(fail[ResultFamily[V], V](view), accepts, recover)._ok().value[1], 12)
    assert_equal(ceg_else(fail[ResultFamily[V], V](view), accepts, replace)._ok().value[0], 11)
    assert_equal(ceg_recover(fail[ResultFamily[V], V](view), no, recover)._err().value[1], 12)
    assert_equal(ceg_pure_predicate(fail[ResultFamily[V], V](view), pure_accepts, recover)._ok().value[0], 11)
    assert_equal(ceg_pure_handler(fail[ResultFamily[V], V](view), accepts, pure_recover)._ok().value[1], 12)
    comptime Deferred = ReaderT[ResultFamily[V], Int]
    var pending = piped(fail[Deferred, V](view)).recover_if[Deferred](accepts, recover).get()
    var deferred_code: Int
    try:
        var deferred_value = run[Deferred](pending^, 0)
        deferred_code = deferred_value._ok().value[0]
    except error:
        comptime assert type_of(error) == V
        deferred_code = -1
    assert_equal(deferred_code, 11)
    def predicate_raises(error: V) raises V -> Bool: raise error
    def handler_raises(var error: V) raises V -> V: raise error
    var code = 0
    try:
        _ = ceg_recover(fail[ResultFamily[V], V](view), predicate_raises, recover)
    except error:
        comptime assert type_of(error) == V
        code = error[1]
    assert_equal(code, 12)
    try:
        _ = ceg_recover(fail[ResultFamily[V], V](view), accepts, handler_raises)
    except error:
        comptime assert type_of(error) == V
        code = error[0]
    assert_equal(code, 11)


def main() raises:
    ceg_origins([11, 12])
    print("conditional error generic: ok")
