from fp.callables import BorrowCallContract, BorrowMutableCallable, UnaryContract, MutableUnary

@fieldwise_init
struct Handler[R: Copyable & Deinitable = Int, X: Movable & Deinitable = Never, A: Movable & Deinitable = Int](BorrowMutableCallable, MutableUnary):
    comptime Payload = Self.A
    comptime Result = Self.R
    comptime Failure = Self.X
    comptime Arg = Self.A
    comptime Out = Self.R
    comptime Error = Self.X
    var output: Self.R
    var calls: Int
    def invoke_mut(mut self, ref value: Self.A) raises Self.X -> Self.R:
        self.calls += 1
        return self.output.copy()
    def call_mut(mut self, var value: Self.A) raises Self.X -> Self.R:
        return self.invoke_mut(value)

@fieldwise_init
struct Bare(BorrowCallContract, UnaryContract, Movable):
    comptime Payload = Int
    comptime Result = Int
    comptime Arg = Int
    comptime Out = Int


from fp.callables import Unary, BorrowCallable
@fieldwise_init
struct Shared(Unary,BorrowCallable):
    comptime Arg=Int
    comptime Payload=Int
    comptime Out=Int
    comptime Result=Int
    var offset:Int
    def call(self,var value:Int)->Int: return value+self.offset
    def invoke(self,ref value:Int)->Int: return value+self.offset
