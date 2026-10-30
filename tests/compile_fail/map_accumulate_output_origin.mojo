# error: origin_of(local)
from fp.iteration import map_accumulate
from fp.callables import Binary

@fieldwise_init
struct OutputStep[o:ImmOrigin](Binary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Tuple[Int,Pointer[List[Int],Self.o]]
    var pointer:Pointer[List[Int],Self.o]
    def call(self,var carry:Int,var item:Int)->Self.Out: return (carry+item,self.pointer)

def check(anchor:List[Int]):
    var local:List[Int]=[1,2]
    var expected=map_accumulate(range(2),0,OutputStep(Pointer(to=anchor)))
    var actual=map_accumulate(range(2),0,OutputStep(Pointer(to=local)))
    expected=actual^
def main():
    var anchor:List[Int]=[1,2]
    check(anchor)
