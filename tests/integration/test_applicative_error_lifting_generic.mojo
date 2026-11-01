"""Generic forwarding preserves callback, payload, environment and error origins."""
from fp.algebra import ApplicativeError, ResultFamily, fail
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ReaderAction, run, run_writer
from fp.algebra import StringMonoid
from fp.functions import pipeline
from fp.data import Result
from std.builtin.rebind import rebind_var
from std.os import abort
from std.testing import assert_equal


def aelg_reader[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                F: def(var A) raises E -> R](var error: A, ref handler: F
) raises E -> Result[R, A]:
    comptime I = ReaderT[ResultFamily[A], Int]
    var pending = pipeline[I](fail[I, R](error^)).raising[E]().recover(handler).get()
    var environment = 5
    try:
        return rebind_var[Result[R, A]](run[I](pending^, environment))
    except raised:
        comptime if type_of(raised) == Never:
            abort("unreachable error")
        else:
            comptime assert type_of(raised) == E
            raise rebind_var[E](raised^)


def aelg_state[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
               F: def(var A) raises E -> R](var error: A, ref handler: F
) raises E -> Result[Tuple[R, Int], A]:
    comptime I = StateT[ResultFamily[A], Int]
    var pending = pipeline[I](fail[I, R](error^)).raising[E]().recover(handler).get()
    try:
        return rebind_var[Result[Tuple[R, Int], A]](run[I](pending^, 8))
    except raised:
        comptime if type_of(raised) == Never:
            abort("unreachable error")
        else:
            comptime assert type_of(raised) == E
            raise rebind_var[E](raised^)


def aelg_origins(values: List[Int]) raises:
    var view = Span(values)
    comptime V = type_of(view)
    def restore(var error: V) raises V -> V: return error
    var read = aelg_reader(view, restore)
    comptime assert type_of(read) == Result[V, V]
    assert_equal(read._ok().value[1], 12)
    var state = aelg_state(view, restore)
    comptime assert type_of(state) == Result[Tuple[V, Int], V]
    assert_equal(state._ok().value[0][0], 11)
    assert_equal(state._ok().value[1], 8)
    def raised(var error: V) raises V -> V: raise error
    var code = 0
    try:
        _ = aelg_reader(view, raised)
    except error:
        comptime assert type_of(error) == V
        code = error[1]
    assert_equal(code, 12)
    code = 0
    try:
        _ = aelg_state(view, raised)
    except error:
        comptime assert type_of(error) == V
        code = error[0]
    assert_equal(code, 11)
    comptime W = WriterT[ResultFamily[V], StringMonoid]
    def plain(var error: V) -> V: return error
    var written = pipeline[W](fail[W, V](view)).recover(plain).get()
    var storage = run_writer[W](written^)
    comptime assert type_of(storage) == Result[Tuple[String, V], V]
    assert_equal(storage._ok().value[1][1], 12)
    comptime O = OptionalT[ResultFamily[V]]
    var optional = pipeline[O](fail[O, V](view)).recover(plain).get()
    comptime assert type_of(optional) == Result[Optional[V], V]
    assert_equal(optional._ok().value.value()[1], 12)


def main() raises:
    aelg_origins([11, 12])
    print("applicative error lifting generic: ok")
