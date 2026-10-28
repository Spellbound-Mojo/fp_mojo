"""Invalid receivers and origin-carrying factories for shared-reference diagnostics."""
from fp.callables import Thunk,Unary,UnaryContract,MutableUnary,OnceUnary,MutableBinary,OnceBinary,MutableThunk,OnceThunk,BorrowMutableCallable,BorrowOnceCallable
@fieldwise_init
struct Bare(UnaryContract,Movable):
    comptime Arg=Int
    comptime Out=Int

@fieldwise_init
struct BinaryMut(MutableBinary):
    comptime Arg=Int
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Payload=Int
    comptime Result=Int
    def call_mut(mut self,var first:Int,var second:Int)->Int:return first+second

@fieldwise_init
struct BinaryOnce(OnceBinary):
    comptime Arg=Int
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Payload=Int
    comptime Result=Int
    def call_once(deinit self,var first:Int,var second:Int)->Int:return first+second

@fieldwise_init
struct BorrowMut(BorrowMutableCallable):
    comptime Arg=Int
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Payload=Int
    comptime Result=Int
    def invoke_mut(mut self,ref value:Int)->Int:return value

@fieldwise_init
struct BorrowOnce(BorrowOnceCallable):
    comptime Arg=Int
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Payload=Int
    comptime Result=Int
    def invoke_once(deinit self,ref value:Int)->Int:return value

@fieldwise_init
struct Callback(Unary):
    comptime Arg=Int
    comptime Out=Int
    var offset:Int
    def call(self,var value:Int)->Int:return value+self.offset

@fieldwise_init
struct ThunkMut(MutableThunk):
    comptime Arg=Int
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Payload=Int
    comptime Result=Int
    def call_mut(mut self)->Int:return 1

@fieldwise_init
struct ThunkOnce(OnceThunk):
    comptime Arg=Int
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Payload=Int
    comptime Result=Int
    def call_once(deinit self)->Int:return 1

@fieldwise_init
struct UnaryMut(MutableUnary):
    comptime Arg=Int
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Payload=Int
    comptime Result=Int
    def call_mut(mut self,var value:Int)->Int:return value

@fieldwise_init
struct UnaryOnce(OnceUnary):
    comptime Arg=Int
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    comptime Payload=Int
    comptime Result=Int
    def call_once(deinit self,var value:Int)->Int:return value

@fieldwise_init
struct Failure[o: ImmOrigin](Thunk):
    comptime Out = Int
    comptime Error = Span[Int, Self.o]
    var values: Self.Error
    def call(self) raises Self.Error -> Int:
        raise self.values
