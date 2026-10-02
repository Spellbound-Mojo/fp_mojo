"""Consuming Result bridge: one receiver, exact failures, no copied owners."""
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from fp.callables import Thunk, OnceThunk
from fp.data import Result, Ok, Err, attempt_once


@fieldwise_init
struct Trace(Movable):
    var calls: Int
    var drops: SIMD[DType.int64, 4]


@fieldwise_init
struct Token[kind: Int](Movable):
    var value: Int
    var trace: ArcPointer[Trace]
    def __deinit__(deinit self):
        self.trace[].drops[Self.kind] += 1


@fieldwise_init
struct Consume(OnceThunk):
    var state: Token[1]
    var value: Token[2]
    var unused: Token[3]
    var fail: Bool
    comptime Out = Token[2]
    comptime Error = Token[2]
    def call_once(deinit self) raises Token[2] -> Token[2]:
        self.state.trace[].calls += 1
        var value = self.value^
        value.value += self.state.value
        if self.fail:
            raise value^
        return value^


def capture[F: OnceThunk](var callback: F) -> Result[F.Out, F.Error]:
    return attempt_once(callback^)


def forward[F: OnceThunk](var callback: F) -> Result[F.Out, F.Error]:
    return capture(callback^)


@fieldwise_init
struct Dual(Thunk, OnceThunk, ImplicitlyCopyable):
    comptime Out = Int
    def call(self) -> Int:
        return 1
    def call_once(deinit self) -> Int:
        return 2


@fieldwise_init
struct Nested(OnceThunk):
    comptime Out = Result[Int, Int]
    def call_once(deinit self) -> Result[Int, Int]:
        return Result[Int, Int](Err(7))


@fieldwise_init
struct Stop(OnceThunk):
    comptime Out = Int
    comptime Error = StopIteration
    def call_once(deinit self) raises StopIteration -> Int:
        raise StopIteration()


def expected_ok[T: Movable & Deinitable, E: Movable & Deinitable](var value: Result[T, E]) raises -> T:
    try:
        return value^.raise_on_err()
    except:
        raise Error('expected a successful Result')


@fieldwise_init
struct External[origin: ImmOrigin](OnceThunk):
    var pointer: Pointer[String, Self.origin]
    var fail: Bool
    comptime Out = Pointer[String, Self.origin]
    comptime Error = Pointer[String, Self.origin]
    def call_once(deinit self) raises Self.Error -> Self.Out:
        if self.fail:
            raise self.pointer
        return self.pointer


def main() raises:
    var trace = ArcPointer(Trace(0, SIMD[DType.int64, 4](0)))
    var success = forward(Consume(Token[1](10, trace), Token[2](4, trace), Token[3](8, trace), False))
    comptime assert type_of(success) == Result[Token[2], Token[2]]
    assert_true(success.is_ok())
    assert_equal(trace[].calls, 1)
    assert_equal(trace[].drops, SIMD[DType.int64, 4](0, 1, 0, 1))
    var value = expected_ok(success^)
    assert_equal(value.value, 14)
    _ = value^
    assert_equal(trace[].drops[2], 1)

    var failure = forward(Consume(Token[1](10, trace), Token[2](-4, trace), Token[3](8, trace), True))
    assert_true(failure.is_err())
    assert_equal(trace[].calls, 2)
    assert_equal(trace[].drops, SIMD[DType.int64, 4](0, 2, 1, 2))
    var caught = False
    try:
        _ = failure^.raise_on_err()
    except error:
        comptime assert type_of(error) == Token[2]
        caught = True
        assert_equal(error.value, 6)
    assert_true(caught)
    assert_equal(trace[].drops, SIMD[DType.int64, 4](0, 2, 2, 2))

    # A thunk with both shared and consuming modes is consumed.
    var pure = attempt_once(Dual())
    comptime assert type_of(pure) == Result[Int, Never]
    assert_equal(pure^.raise_on_err(), 2)
    var nested = attempt_once(Nested())
    comptime assert type_of(nested) == Result[Result[Int, Int], Never]
    var inner = nested^.raise_on_err()
    assert_true(inner.is_err())
    var stopped = attempt_once(Stop())
    comptime assert type_of(stopped) == Result[Int, StopIteration]
    assert_true(stopped.is_err())

    var owner = String('external owner')
    var address = expected_ok(forward(External(Pointer(to=owner), False)))
    assert_true(address == Pointer(to=owner))
    var failed_view = forward(External(Pointer(to=owner), True))
    var saw_external_error = False
    try:
        _ = failed_view^.raise_on_err()
    except error:
        saw_external_error = True
        comptime assert type_of(error) == Pointer[String, ImmOrigin(origin_of(owner))]
        assert_true(error == Pointer(to=owner))
    assert_true(saw_external_error)
    print('attempt_once: ok')
