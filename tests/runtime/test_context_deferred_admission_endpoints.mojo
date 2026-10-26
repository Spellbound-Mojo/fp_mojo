"""A transformer base owns endpoint admission even when its representation belongs to a deeper layer."""
from fp.algebra import Monad, StringMonoid
from fp.effects import Reader, ReaderT, StateT, WriterT, WriterFamily, ReaderFamily, OptionalT, ResultT, run, action, run_writer
from fp.callables import BorrowCallable, Unary
from std.testing import assert_equal

def forward_endpoint[I: ReaderFamily, T: Movable & Deinitable, F: Movable & Deinitable](var callback: F) -> I.Endpoint[T, F] where I.EndpointCompatible[T, F]:
    return action[I, T](callback^)

def forward_unwrap[I: WriterFamily, V: Movable & Deinitable](var value: V) -> I.Unwrapped[V] where I.CarrierCompatible[V]:
    return run_writer[I](value^)

@fieldwise_init
struct ReadLayer[I: Monad](BorrowCallable):
    comptime Payload = Int
    comptime Result = Self.I.Pure[Int]
    def invoke(self, ref value: Int) raises Never capturing -> Self.Result:
        return Self.I.pure(value + 1)

@fieldwise_init
struct StepLayer[I: Monad](Unary):
    comptime Arg = Int
    comptime Out = Self.I.Pure[Tuple[Int, Int]]
    def call(self, var state: Int) -> Self.Out:
        return Self.I.pure(Tuple(state, state + 1))

def main() raises:
    comptime Base = Reader[Int]
    comptime O = OptionalT[Base]
    comptime R = ReaderT[O, Int]
    comptime S = StateT[O, Int]
    # O's representation records Base as its computation family, so comparing
    # the nominal Family directly to O would incorrectly reject these endpoints.
    var reader = forward_endpoint[R, Int](ReadLayer[O]())
    var outer = run[R](reader^, 8)
    var inner = run[Base](outer^, 0)
    assert_equal(inner.take(), 9)
    var state = action[S, Int](StepLayer[O]())
    var changed = run[S](state^, 8)
    var optional_pair = run[Base](changed^, 0)
    var pair = optional_pair.take()
    assert_equal(pair[0], 8)
    assert_equal(pair[1], 9)
    comptime X = ResultT[Base, String]
    comptime RX = ReaderT[X, Int]
    var result = run[RX](action[RX, Int](ReadLayer[X]()), 12)
    assert_equal(run[Base](result^, 0)._ok().value, 13)
    comptime W = WriterT[Base, StringMonoid]
    var unwrapped = forward_unwrap[W](W.pure(17))
    assert_equal(run[Base](unwrapped^, 0)[1], 17)
