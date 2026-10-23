"""Generic native/library callbacks keep exact payload and error origins."""
from fp.functions import kleisli
from fp.algebra import ResultFamily, OptionalFamily
from fp.data import Result, Ok
from fp.callables import Unary, UnaryContract, NativeUnary, call_once
from std.builtin.rebind import rebind_var
from std.testing import assert_equal


def kg_native[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
              F: def(var A) raises E -> R](var f: F, var value: A) raises E -> R where R == ResultFamily[String].Pure[ResultFamily[String].Element[R]]:
    var result = kleisli[ResultFamily[String]](NativeUnary[A, R, E, F, True](f^)).call_once(value^)
    comptime assert type_of(result) == R
    return rebind_var[R](result^)


def kg_library[F: UnaryContract & Movable & Deinitable](var f: F, var value: F.Arg) raises F.Error -> F.Out:
    return call_once(f^, value^)

@fieldwise_init
struct KGView[o: ImmOrigin](Unary):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Optional[Span[Int, Self.o]]
    def call(self, var arg: Self.Arg) -> Self.Out: return Optional(arg)

@fieldwise_init
struct KGViewError[o: ImmOrigin](Unary):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Optional[Int]
    comptime Error = Span[Int, Self.o]
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out: raise arg


def kg_views(values: List[Int]) raises:
    var view = Span(values)
    comptime View = type_of(view)
    def keep(var x: View) raises String -> Result[View, String]: return Ok(x)
    var output: View
    try:
        output = kg_native(keep, view).raise_on_err()
    except:
        raise Error("unexpected native failure")
    assert_equal(output[1], 8)
    var chain = kleisli[OptionalFamily](KGView[origin_of(values)]()).then(KGView[origin_of(values)]())
    var same = chain.call(view)
    comptime assert type_of(same) == Optional[View]
    assert_equal(same.take()[0], 7)
    var moved = kg_library(chain^, view)
    assert_equal(moved.take()[1], 8)
    var code = 0
    try:
        _ = kleisli[OptionalFamily](KGView[origin_of(values)]()).then(KGViewError[origin_of(values)]()).call_once(view)
    except error:
        comptime assert type_of(error) == View
        code = error[1]
    assert_equal(code, 8)
    # Native callbacks can raise a borrowed view passed as their explicit input.
    def fail(var x: View) raises View -> Optional[Int]: raise x
    try:
        _ = kleisli[OptionalFamily](KGView[origin_of(values)]()).then(fail).call_once(view)
    except error:
        comptime assert type_of(error) == View
        code = error[0]
    assert_equal(code, 7)


def main() raises:
    kg_views([7, 8])
