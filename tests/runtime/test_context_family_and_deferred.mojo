from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct ContextFamilyAndDeferredSliceFault(Movable):
    var code: Int
from fp.algebra import OptionalFamily
from fp.effects import ReaderT, run
from fp.algebra.protocols import Functor
from fp.functions import Pipeline
def explicit[V: Movable & Deinitable, //, I: Functor](var value: V) -> Pipeline[I, V]:
    return piped[I](value^)
def main() raises:
    var calls = 0
    def transform(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + 1
    var optional = explicit[OptionalFamily](Optional(3)).map(transform).get()
    assert_equal(optional.take(), 4)
    comptime Family = ReaderT[OptionalFamily, Int]
    var pending = piped[Family](Family.pure(5)).map(transform).get()
    assert_equal(calls, 1)
    var result = run[Family](pending^, 0)
    assert_equal(result.take(), 6)
    assert_equal(calls, 2)
