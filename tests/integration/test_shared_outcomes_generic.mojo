"""Generic forwarding keeps success, stored-error and raised-error origins."""
from fp.algebra import ResultFamily, fail
from fp.data import Result, Ok, Err
from fp.functions import piped
from fp.effects import ReaderT, run
from std.testing import assert_equal
from std.builtin.rebind import rebind_var


def sog_ensure[T: Movable & Deinitable, E: Movable & Deinitable, X: Movable & Deinitable,
               F: def(T) raises X -> Bool, G: def(T) raises X -> E](
    var source: Result[T, E], ref predicate: F, ref factory: G
) raises X -> Result[T, E]:
    return piped(source^).ensure[ResultFamily[E], R=Bool, S=E, X=X, Y=X, Z=X](predicate, factory).get()


def sog_redeem[T: Movable & Deinitable, E: Movable & Deinitable, U: Movable & Deinitable, X: Movable & Deinitable,
               F: def(var T) raises X -> U, G: def(var E) raises X -> U](
    var source: Result[T, E], ref success: F, ref failure: G
) raises X -> Result[U, E]:
    return piped(source^).redeem[ResultFamily[E], R=U, S=U, X=X, Y=X, Z=X](success, failure).get()


def sog_with[T: Movable & Deinitable, E: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable,
             F: def(var T) raises X -> R, G: def(var E) raises X -> R](
    var source: Result[T, E], ref success: F, ref failure: G
) raises X -> R where R == Result[ResultFamily[E].Element[R], E]:
    comptime assert R == Result[ResultFamily[E].Element[R], E]
    return rebind_var[R](piped(source^).redeem_with[ResultFamily[E], R=R, S=R, X=X, Y=X, Z=X](success, failure).get())


def sog_tap[T: Movable & Deinitable, E: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable,
            F: def(Result[T, E]) raises X -> R](
    var source: Result[T, E], ref inspect: F
) raises X -> Result[T, E] where R == Result[ResultFamily[E].Element[R], E]:
    return piped(source^).attempt_tap[ResultFamily[E], R=R, X=X, Z=X](inspect).get()


def sog_origins(values: List[Int]) raises:
    var view = Span(values)
    comptime V = type_of(view)
    comptime R = Result[V, V]
    comptime F = ResultFamily[V]
    def reject(value: V) raises V -> Bool: return False
    def make_error(value: V) raises V -> V: return value
    def identity(var value: V) raises V -> V: return value
    def effect(var value: V) raises V -> R: return Err(value)
    def observe(outcome: R) raises V -> R: return Ok(outcome._err().value)
    var checked = sog_ensure(R(Ok(view)), reject, make_error)
    assert_equal(checked._err().value[0], 9)
    assert_equal(sog_redeem(checked^, identity, identity)._ok().value[1], 12)
    assert_equal(sog_with(R(Ok(view)), effect, effect)._err().value[0], 9)
    assert_equal(sog_tap(R(Err(view)), observe)._err().value[1], 12)
    def raised(var value: V) raises V -> V: raise value
    var code = 0
    try:
        _ = sog_redeem(R(Ok(view)), raised, identity)
    except error:
        comptime assert type_of(error) == V
        code = error[1]
    assert_equal(code, 12)
    comptime D = ReaderT[F, Int]
    def deferred(outcome: R) -> D.Pure[V]: return D.pure(outcome._err().value)
    var pending = piped(fail[D, V](view)).attempt_tap[D](deferred).get()
    var retained = run[D](pending^, 3)
    comptime assert type_of(retained) == R
    assert_equal(retained._err().value[0], 9)


def main() raises:
    sog_origins([9, 12])
    print("shared outcomes generic: ok")
