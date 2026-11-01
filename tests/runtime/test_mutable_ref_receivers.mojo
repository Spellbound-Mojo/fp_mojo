"""A reference preserves shared fallback and never consumes the original receiver."""
from fp.callables import (
    CallContract, UnaryContract, Unary, MutableUnary, OnceUnary,
    Binary, MutableBinary, Thunk, MutableThunk, BorrowCallable,
    BorrowMutableCallable, BorrowOnceCallable, RepeatableUnary, RepeatableBinary,
    RepeatableThunk, RepeatableBorrow, call_once, call_repeated,
    invoke_borrowed_once, mut_ref,
)
from std.testing import assert_equal


@fieldwise_init
struct Modes(Unary, MutableUnary, OnceUnary, BorrowCallable, BorrowMutableCallable, BorrowOnceCallable):
    comptime Arg = Int
    comptime Out = Int
    comptime Payload = Int
    comptime Result = Int
    var calls: Int
    def call(self, var value: Int) -> Int: return -1
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return value + self.calls
    def call_once(deinit self, var value: Int) -> Int: return -2
    def invoke(self, ref value: Int) -> Int: return -3
    def invoke_mut(mut self, ref value: Int) -> Int:
        self.calls += 1
        return value + self.calls
    def invoke_once(deinit self, ref value: Int) -> Int: return -4


struct Shared(Unary, Binary, Thunk, BorrowCallable):
    comptime Arg = Int
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Payload = Int
    comptime Result = Int
    def __init__(out self): pass
    def call(self, var value: Int) -> Int: return value + 1
    def call(self, var first: Int, var second: Int) -> Int: return first + second
    def call(self) -> Int: return 9
    def invoke(self, ref value: Int) -> Int: return value * 2


@fieldwise_init
struct Conditional[unary: Bool](
    CallContract, Movable, Deinitable,
    MutableUnary where unary, MutableBinary where not unary,
):
    comptime Arg = Int
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var value: Int) -> Int where Self.unary:
        self.calls += 1
        return value + self.calls
    def call_mut(mut self, var first: Int, var second: Int) -> Int where not Self.unary:
        self.calls += 1
        return first + second + self.calls


struct OnlyOnce(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def __init__(out self): pass
    def call_once(deinit self, var value: Int) -> Int: return value


def main() raises:
    comptime assert not RepeatableUnary[Int] and not RepeatableBinary[Int]
    comptime assert not RepeatableThunk[Int] and not RepeatableBorrow[Int]
    comptime assert not RepeatableUnary[OnlyOnce]
    var modes = Modes(0)
    assert_equal(call_once(mut_ref(modes), 10), 11)
    var value = 20
    assert_equal(invoke_borrowed_once[Never](value, mut_ref(modes)), 22)
    assert_equal(modes.calls, 2)
    var shared = Shared()
    var view = mut_ref(shared)
    comptime assert not conforms_to(type_of(view), Copyable)
    assert_equal(call_repeated(view, 1), 2)
    assert_equal(call_repeated(view, 2, 3), 5)
    assert_equal(call_repeated(view), 9)
    assert_equal(invoke_borrowed_once[Never](value, view^), 40)
    assert_equal(shared.call(), 9)
    var unary = Conditional[True](0)
    var binary = Conditional[False](0)
    assert_equal(call_once(mut_ref(unary), 5), 6)
    assert_equal(call_once(mut_ref(binary), 5, 6), 12)
    assert_equal(unary.calls, 1)
    assert_equal(binary.calls, 1)
