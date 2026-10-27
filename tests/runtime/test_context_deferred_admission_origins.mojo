from fp.algebra import Monad, ResultFamily, ListMonoid
from fp.functions import pipeline
from fp.effects import ReaderT, StateT, Reader, ReaderAction, ReaderFamily, StateAction, StateFamily, WriterT, OptionalT, ResultT, run, writer, run_writer
from fp.callables import Unary, UnaryContract
from fp.data import Result, Ok, Err
from std.testing import assert_equal

@fieldwise_init
struct Keep[T: Movable & Deinitable](Unary):
    comptime Arg = Self.T
    comptime Out = Self.T
    def call(self, var value: Self.T) -> Self.T: return value^

@fieldwise_init
struct Next[I: Monad, T: Movable & Deinitable](Unary):
    comptime Arg = Self.T
    comptime Out = Self.I.Mapped[Self.I.Pure[Self.T], Keep[Self.T]]
    comptime Error = Self.I.MapError[Self.I.Pure[Self.T], Keep[Self.T]]
    def call(self, var value: Self.T) raises Self.Error -> Self.Out:
        return Self.I.map(Keep[Self.T](), Self.I.pure(value^))

def forward[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var value: V, var callback: F) raises I.BindError[V, F] -> I.Bound[V, F] where I.BindCompatible[V, F] and I.Element[V] == F.Arg:
    return pipeline[I](value^).flat_map(callback^).get()

def forward_run[I: ReaderFamily, V: ReaderAction, o: ImmOrigin](var value: V, ref[o] environment: I.Environment) raises V.Error[o] -> V.Out[o] where I.RunCompatible[V, o]:
    return run[I](value^, environment)

def forward_state[I: StateFamily, V: StateAction](var value: V, var state: I.StateType) raises V.Error -> V.Out where I.RunCompatible[V]:
    return run[I](value^, state^)

def check(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    comptime R = ReaderT[ResultFamily[View], Int]
    var result = forward_run[R](forward[R](R.pure(view), Next[R, View]()), 0)
    assert_equal(Pointer(to=result._ok().value[0]) == Pointer(to=owner[0]), True)
    var failed = run[R](forward[R](R.lift(Result[View, View](Err(view))), Next[R, View]()), 0)
    assert_equal(Pointer(to=failed._err().value[1]) == Pointer(to=owner[1]), True)
    comptime S = StateT[ResultFamily[View], Int]
    var state = forward_state[S](forward[S](S.pure(view), Next[S, View]()), 17)
    assert_equal(Pointer(to=state._ok().value[0][1]) == Pointer(to=owner[1]), True)
    assert_equal(state._ok().value[1], 17)
    comptime X = ResultT[Reader[Int], View]
    var layer = run[Reader[Int]](forward[X](X.pure(view), Next[X, View]()), 0)
    assert_equal(Pointer(to=layer._ok().value[0]) == Pointer(to=owner[0]), True)
    comptime W = WriterT[Reader[Int], ListMonoid[View]]
    var logged = writer[W, View](Reader[Int].pure(Tuple(List[View]([view]), view)))
    var unwrapped = run_writer[W](logged^)
    var pair = run[Reader[Int]](unwrapped^, 0)
    assert_equal(Pointer(to=pair[0][0][0]) == Pointer(to=owner[0]), True)
    assert_equal(Pointer(to=pair[1][1]) == Pointer(to=owner[1]), True)

def main() raises:
    var owner = List[Int]([7, 11])
    check(owner)
