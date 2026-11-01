from fp.callables import Thunk
from fp.effects import Reader,run
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Factory(Thunk):
    comptime Out=Reader[Int].Pure[Int]
    comptime Error=Int
    var calls:ArcPointer[Int]
    var fail:Bool
    def call(self) raises Int -> Self.Out:
        self.calls[]+=1
        if self.fail:raise 7
        return Reader[Int].pure(9)


@fieldwise_init
struct Maker[V:Copyable & Deinitable,X:Movable & Deinitable=Never](Thunk):
    comptime Out=Self.V
    comptime Error=Self.X
    var value:Self.V
    def call(self) raises Self.Error -> Self.Out:return self.value.copy()

from fp.callables import Unary,BorrowCallable
@fieldwise_init
struct Projection[V:Copyable & Deinitable](Unary,BorrowCallable):
    comptime Arg=Int
    comptime Payload=Int
    comptime Out=Self.V
    comptime Result=Self.V
    var value:Self.V
    def call(self,var value:Int)->Self.Out:return self.value.copy()
    def invoke(self,ref value:Int)->Self.Result:return self.value.copy()
