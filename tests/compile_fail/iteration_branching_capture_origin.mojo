# error: origin_of(local)
from fp.iteration import partition, Unbounded
from fp.callables import BorrowCallable

@fieldwise_init
struct I3BorrowedPredicate[o: ImmOrigin](BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    var pointer: Pointer[Int,Self.o]
    def invoke(self, ref payload: Self.Payload) raises Never capturing -> Self.Result:
        return payload > self.pointer[]

def check(anchor: Int):
    var local = 2
    var expected = partition(I3BorrowedPredicate(Pointer(to=anchor)),range(3),buffer=Unbounded())
    var actual = partition(I3BorrowedPredicate(Pointer(to=local)),range(3),buffer=Unbounded())
    expected = actual^
def main(): check(1)
