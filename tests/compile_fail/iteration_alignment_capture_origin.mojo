# error: origin_of(local)
from fp.iteration import align_with
from fp.data import Ior
from fp.callables import Unary

@fieldwise_init
struct I4Borrowed[o: ImmOrigin](Unary):
    comptime Arg = Ior[Int,Int]
    comptime Out = Pointer[Int,Self.o]
    var pointer: Self.Out
    def call(self,var value:Self.Arg)->Self.Out: return self.pointer

def check(anchor: Int):
    var local=2
    var expected=align_with(I4Borrowed(Pointer(to=anchor)),range(1),range(1))
    var actual=align_with(I4Borrowed(Pointer(to=local)),range(1),range(1))
    expected=actual^
def main(): check(1)
