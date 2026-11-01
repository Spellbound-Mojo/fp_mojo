from fp.callables import Thunk
@fieldwise_init
struct Factory[T:Copyable & Deinitable,X:Movable & Deinitable=Never](Thunk):
    comptime Out=Self.T
    comptime Error=Self.X
    var value:Self.T
    def call(self) raises Self.X -> Self.T: return self.value.copy()
