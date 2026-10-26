from fp.algebra import Functor, Monad, Applicative, ListFamily, StringMonoid, ResultFamily
from fp.functions import pipeline
from fp.effects import Reader, ReaderT, State, StateT, Writer, WriterT, OptionalT, ResultT, run, run_writer
from fp.callables import Unary, UnaryContract
from fp.data import Result, Ok
from std.testing import assert_equal

@fieldwise_init
struct Inc(Unary):
    comptime Arg = Int
    comptime Out = Int
    def call(self, var value: Int) -> Int: return value + 1

@fieldwise_init
struct Next[I: Monad](Unary):
    comptime Arg = Int
    comptime Out = Self.I.Mapped[Self.I.Pure[Int], Inc]
    comptime Error = Self.I.MapError[Self.I.Pure[Int], Inc]
    def call(self, var value: Int) raises Self.Error -> Self.Out:
        return Self.I.map(Inc(), Self.I.pure(value))

def forward[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var value: V, var callback: F) raises I.BindError[V, F] -> I.Bound[V, F] where I.BindCompatible[V, F] and I.Element[V] == F.Arg:
    return pipeline[I](value^).flat_map(callback^).get()

def check[I: Monad]() raises:
    comptime assert I.CarrierCompatible[I.Pure[Int]]
    comptime assert I.CarrierCompatible[Next[I].Out]
    comptime assert I.BindCompatible[I.Pure[Int], Next[I]]

def main() raises:
    comptime R = Reader[Int]
    comptime S = State[Int]
    comptime W = Writer[StringMonoid]
    comptime O = OptionalT[R]
    comptime X = ResultT[S, String]
    check[R](); check[S](); check[W](); check[O](); check[X]()
    comptime assert not R.CarrierCompatible[Int]
    comptime assert not S.CarrierCompatible[Int]
    comptime assert not W.CarrierCompatible[Int]
    comptime assert not O.CarrierCompatible[Int]
    comptime assert not X.CarrierCompatible[Int]
    comptime assert not O.CarrierCompatible[R.Pure[List[Int]]]
    comptime assert not X.CarrierCompatible[S.Pure[Result[Int, Int]]]
    comptime assert not R.CarrierCompatible[Reader[String].Pure[Int]]
    assert_equal(run[R](forward[R](R.pure(1), Next[R]()), 0), 2)
    assert_equal(run[S](forward[S](S.pure(2), Next[S]()), 9)[0], 3)
    assert_equal(run_writer[W](forward[W](W.pure(3), Next[W]()))[1], 4)
    var optional = run[R](forward[O](O.pure(4), Next[O]()), 0)
    assert_equal(optional.take(), 5)
    var result = run[S](forward[X](X.pure(5), Next[X]()), 9)
    assert_equal(result[0]._ok().value, 6)
    def later(var x: Int) -> Next[R].Out: return R.map(Inc(), R.pure(x))
    var pending = pipeline(List[Int]([1, 2])).traverse[R](later).get()
    assert_equal(run[R](pending^, 0), List[Int]([2, 3]))
    def add(var a: Int, var b: Int) -> Int: return a + b
    var paired = pipeline[R](R.pure(1)).map2(later(2), add).get()
    assert_equal(run[R](paired^, 0), 4)
    def left() -> R.Pure[Int]: return R.pure(8)
    def right() -> Next[R].Out: return later(10)
    var chosen = pipeline[R](R.pure(False)).if_effect(left, right).get()
    comptime assert R.CarrierCompatible[type_of(chosen)]
    assert_equal(run[R](chosen^, 0), 11)
