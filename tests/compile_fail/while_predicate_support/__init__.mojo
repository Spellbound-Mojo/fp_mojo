from fp.callables import BorrowCallContract, BorrowMutableCallable, BorrowOnceCallable, MutableUnary
@fieldwise_init
struct Predicate[R: Copyable & Deinitable = Bool, X: Movable & Deinitable = Never, A: Movable & Deinitable = Int](BorrowMutableCallable):
    comptime Payload = Self.A
    comptime Result = Self.R
    comptime Failure = Self.X
    var output: Self.R
    var calls: Int
    def invoke_mut(mut self, ref value: Self.A) raises Self.X -> Self.R:
        self.calls += 1
        return self.output.copy()
@fieldwise_init
struct Body[X: Movable & Deinitable = Never](MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Self.X
    var calls: Int
    def call_mut(mut self, var value: Int) raises Self.X -> Int:
        self.calls += 1
        return value + 1
@fieldwise_init
struct Bare(BorrowCallContract, Movable):
    comptime Payload = Int
    comptime Result = Bool
@fieldwise_init
struct Once(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke_once(deinit self, ref value: Int) -> Bool: return False
@fieldwise_init
struct Both(BorrowMutableCallable, MutableUnary):
    comptime Payload = Int
    comptime Result = Bool
    comptime Arg = Int
    comptime Out = Int
    var calls: Int
    def invoke_mut(mut self, ref value: Int) -> Bool:
        self.calls += 1
        return value < 4
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return value + 1
