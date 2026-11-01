from fp.callables import BinaryContract, MutableBinary, OnceBinary
@fieldwise_init
struct Step[R: Copyable & Deinitable = Int, X: Movable & Deinitable = Never, A: Movable & Deinitable = Int, B: Movable & Deinitable = Int](MutableBinary):
    comptime First = Self.A
    comptime Second = Self.B
    comptime Out = Self.R
    comptime Error = Self.X
    var output: Self.R
    def call_mut(mut self, var first: Self.A, var second: Self.B) raises Self.X -> Self.R:
        return self.output.copy()
@fieldwise_init
struct Once[R: Movable & Deinitable = Int](OnceBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Self.R
    var output: Self.R
    def call_once(deinit self, var first: Int, var second: Int) -> Self.R:
        return self.output^
@fieldwise_init
struct Bare(BinaryContract, Movable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
