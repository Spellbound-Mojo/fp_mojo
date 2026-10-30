# error: origin_of(local)
from fp.iteration import scan_map
from fp.callables import Binary

@fieldwise_init
struct I5BorrowedCarry[o:ImmOrigin](Movable):
    var pointer:Pointer[List[Int],Self.o]

@fieldwise_init
struct I5BorrowedStep[o:ImmOrigin](Binary):
    comptime First=I5BorrowedCarry[Self.o]
    comptime Second=Int
    comptime Out=Tuple[Self.First,Int]
    def call(self,var carry:Self.First,var item:Int)->Self.Out:
        var output=carry.pointer[][0]+item
        return (carry^,output)

def check(anchor:List[Int]):
    var local:List[Int]=[1,2]
    var expected=scan_map(range(2),I5BorrowedCarry(Pointer(to=anchor)),I5BorrowedStep[origin_of(anchor)]())
    var actual=scan_map(range(2),I5BorrowedCarry(Pointer(to=local)),I5BorrowedStep[origin_of(local)]())
    expected=actual^
def main():
    var anchor:List[Int]=[1,2]
    check(anchor)
