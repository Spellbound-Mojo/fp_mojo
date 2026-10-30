# error: origin_of(local)
from fp.iteration import scan_map
from fp.callables import Binary

@fieldwise_init
struct I5OutputStep[o:ImmOrigin](Binary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Tuple[Int,Pointer[List[Int],Self.o]]
    var pointer:Pointer[List[Int],Self.o]
    def call(self,var carry:Int,var item:Int)->Self.Out: return (carry+item,self.pointer)

def check(anchor:List[Int]):
    var local:List[Int]=[1,2]
    var expected=scan_map(range(2),0,I5OutputStep(Pointer(to=anchor)))
    var actual=scan_map(range(2),0,I5OutputStep(Pointer(to=local)))
    expected=actual^
def main():
    var anchor:List[Int]=[1,2]
    check(anchor)
