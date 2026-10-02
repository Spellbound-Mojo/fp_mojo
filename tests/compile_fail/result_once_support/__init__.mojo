from fp.callables import OnceUnary
from fp.data import Result, Ok


@fieldwise_init
struct Constant[R: Movable & Deinitable, X: Movable & Deinitable = Never, A: Movable & Deinitable = Int](OnceUnary):
    var result: Self.R
    comptime Arg = Self.A
    comptime Out = Self.R
    comptime Error = Self.X
    def call_once(deinit self, var value: Self.A) raises Self.X -> Self.R:
        return self.result^


@fieldwise_init
struct Address(OnceUnary):
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var value: String) -> Int:
        return value.byte_length()
