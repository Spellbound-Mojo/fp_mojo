"""Imported generic callbacks retain success, stored-error and raised-error origins."""
from fp.algebra import ApplicativeError, ResultFamily, fail
from fp.functions import pipeline
from fp.data import Result, Ok
from std.testing import assert_equal


def aeg_recover[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                F: def(var A) raises E -> R](var source: Result[R, A], ref handler: F
) raises E -> Result[R, A]:
    return pipeline[ResultFamily[A]](source^).raising[E]().recover(handler).get()


def aeg_or_else[A: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable,
                F: def(var A) raises E -> Result[T, A]](var source: Result[T, A], ref handler: F
) raises E -> Result[T, A]:
    return pipeline[ResultFamily[A]](source^).raising[E]().or_else(handler).get()


def aeg_fail[I: ApplicativeError, A: Movable & Deinitable](var error: I.Failure
) raises I.FailError[A] -> I.Failed[A]:
    return fail[I, A](error^)


def aeg_origins(values: List[Int]) raises:
    var view = Span(values)
    comptime V = type_of(view)
    def recover(var error: V) raises V -> V: return error
    def replace(var error: V) raises V -> Result[V, V]: return Ok(error)
    var recovered = aeg_recover(aeg_fail[ResultFamily[V], V](view), recover)
    comptime assert type_of(recovered) == Result[V, V]
    assert_equal(recovered._ok().value[1], 12)
    var handled = aeg_or_else(aeg_fail[ResultFamily[V], V](view), replace)
    comptime assert type_of(handled) == Result[V, V]
    assert_equal(handled._ok().value[0], 11)
    def raised(var error: V) raises V -> V: raise error
    def failed(var error: V) raises V -> Result[V, V]: raise error
    var code = 0
    try:
        _ = aeg_recover(aeg_fail[ResultFamily[V], V](view), raised)
    except error:
        comptime assert type_of(error) == V
        code = error[1]
    assert_equal(code, 12)
    code = 0
    try:
        _ = aeg_or_else(aeg_fail[ResultFamily[V], V](view), failed)
    except error:
        comptime assert type_of(error) == V
        code = error[0]
    assert_equal(code, 11)


def main() raises:
    aeg_origins([11, 12])
    print("applicative error generic: ok")
