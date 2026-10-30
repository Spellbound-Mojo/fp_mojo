from fp.algebra import pure, map, StringMonoid
from fp.effects import OptionalT, Reader, WriterT, WriterFamily, run, run_writer
from fp.functions import pipeline
from fp.callables import OnceUnary, as_unary
from std.memory import ArcPointer
from std.testing import assert_equal
from test_attempt_once import Trace, Token

comptime Base = Reader[Int]
comptime Layer = OptionalT[Base]

def increment(var value: Int) -> Int: return value + 1

def unwrap_once[I: WriterFamily, V: Movable & Deinitable](var value: V) -> I.Unwrapped[V] where I.CarrierCompatible[V]:
    return run_writer[I](value^)

@fieldwise_init
struct Next(OnceUnary):
    var state: Token[1]
    var fail: Bool
    comptime Arg = Int
    comptime Out = Layer.Mapped[Layer.Pure[Int], type_of(as_unary(increment))]
    comptime Error = Token[2]
    def call_once(deinit self, var argument: Int) raises Self.Error -> Self.Out:
        self.state.trace[].calls += 1
        var value = argument + self.state.value
        if self.fail: raise Token[2](value, self.state.trace)
        return map[Layer](pure[Layer](value), as_unary(increment))

def main() raises:
    for present in [False, True]:
        for fail in [False, True]:
            var trace = ArcPointer(Trace(0, SIMD[DType.int64, 4](0)))
            var optional = Optional(3) if present else Optional[Int]()
            var pending = pipeline[Layer](pure[Base](optional^)).flat_map(Next(Token[1](10, trace), fail)).get()
            assert_equal(trace[].calls, 0)
            assert_equal(trace[].drops[1], 0)
            var caught = False
            var result = 0
            try:
                var output = run[Base](pending^, 42)
                if output: result = output.take()
            except error:
                comptime assert type_of(error) == Token[2]
                caught = True
                result = error.value
            assert_equal(caught, present and fail)
            assert_equal(result, (13 if fail else 14) if present else 0)
            assert_equal(trace[].calls, Int(present))
            assert_equal(trace[].drops[1], 1)
            assert_equal(Int(trace[].drops[2]), Int(present and fail))
    var trace = ArcPointer(Trace(0, SIMD[DType.int64, 4](0)))
    var abandoned = pipeline[Layer](pure[Layer](3)).flat_map(Next(Token[1](10, trace), False)).get()
    _ = abandoned^
    assert_equal(trace[].calls, 0)
    assert_equal(trace[].drops[1], 1)
    comptime W = WriterT[Base, StringMonoid]
    for execute in [False, True]:
        var writer_trace = ArcPointer(Trace(0, SIMD[DType.int64, 4](0)))
        var underlying = unwrap_once[W](W.pure(Token[1](30, writer_trace)))
        assert_equal(writer_trace[].drops[1], 0)
        if execute:
            var pair = run[Base](underlying^, 42)
            assert_equal(pair[1].value, 30)
            assert_equal(writer_trace[].drops[1], 0)
            _ = pair^
        else:
            _ = underlying^
        assert_equal(writer_trace[].drops[1], 1)
