"""Generic borrowed observers preserve result, stored-error and raised-error origins."""
from fp.algebra import ResultFamily, fail
from fp.effects import ReaderT, run
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.testing import assert_equal
from std.builtin.rebind import rebind_var


def eog_tap[A: Movable & Deinitable, U: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable,
            F: def(A) raises E -> U](var source: Result[T, A], ref inspect: F) raises E -> Result[T, A]:
    return pipeline[ResultFamily[A]](source^).raising[E]().tap_err(inspect).get()


def eog_flat[A: Movable & Deinitable, U: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable,
             F: def(A) raises E -> Result[U, A]](var source: Result[T, A], ref inspect: F
) raises E -> Result[T, A]:
    return pipeline[ResultFamily[A]](source^).raising[E]().flat_tap_err(inspect).get()


def eog_origins(values: List[Int]) raises:
    var view = Span(values)
    comptime V = type_of(view)
    def observer(error: V) raises V -> Result[V, V]: return Ok(error)
    def failed(error: V) raises V -> Result[V, V]: return Err(error)
    def raised(error: V) raises V -> Result[V, V]: raise error
    var original = eog_tap(fail[ResultFamily[V], V](view), observer)
    comptime assert type_of(original) == Result[V, V]
    assert_equal(original._err().value[1], 12)
    assert_equal(eog_flat(fail[ResultFamily[V], V](view), observer)._err().value[0], 11)
    assert_equal(eog_flat(fail[ResultFamily[V], V](view), failed)._err().value[1], 12)
    # Inferred Result signatures must admit the same embedded origins too.
    var direct = Result[V, V](Err(view)).flat_tap_err(observer)
    assert_equal(direct._err().value[0], 11)
    var inferred: Result[V, V]
    try:
        inferred = pipeline(Result[V, V](Err(view))).raising[V]().flat_tap_err(failed).get()
    except error:
        comptime assert type_of(error) == V
        raise Error("unexpected raised observer error")
    assert_equal(inferred._err().value[1], 12)
    var code = 0
    try:
        _ = eog_flat(fail[ResultFamily[V], V](view), raised)
    except error:
        comptime assert type_of(error) == V
        code = error[0]
    assert_equal(code, 11)
    comptime Deferred = ReaderT[ResultFamily[V], Int]
    def deferred_observer(error: V) raises V -> Deferred.Pure[V]: return Deferred.pure(error)
    var pending = pipeline[Deferred](fail[Deferred, V](view)).raising[V]().tap_err(observer).flat_tap_err(deferred_observer).get()
    var deferred_code: Int
    try:
        var retained = run[Deferred](pending^, 0)
        deferred_code = retained._err().value[1]
    except error:
        comptime assert type_of(error) == V
        deferred_code = -1
    assert_equal(deferred_code, 12)


def main() raises:
    eog_origins([11, 12])
    print("error observation generic: ok")
