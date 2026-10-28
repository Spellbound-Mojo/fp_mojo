# error: origin_of(local)
from fp.iteration import map_accumulate
from fp.callables import Binary

@fieldwise_init
struct OutputStep[o:ImmOrigin](Binary):
    comptime First=Pointer[List[Int],Self.o]
    comptime Second=Int
    comptime Out=Tuple[Self.First,Int]
    var pointer:Pointer[List[Int],Self.o]
    def call(self,var carry:Self.First,var item:Int)->Self.Out: return (carry,item)

def check(anchor:List[Int]):
    var local:List[Int]=[1,2]
    var expected=map_accumulate(OutputStep(Pointer(to=anchor)),Pointer(to=anchor),range(2))
    var actual=map_accumulate(OutputStep(Pointer(to=local)),Pointer(to=local),range(2))
    expected=actual^
def main():
    var anchor:List[Int]=[1,2]
    check(anchor)
