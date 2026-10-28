# error: origin_of(local)
from fp.callables import BorrowMutableCallable
from fp.iteration import pair_with
@fieldwise_init
struct Above[o:ImmOrigin](BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Bool
    var owner:Pointer[List[Int],Self.o]
    def invoke_mut(mut self,ref value:Int)->Bool:return value>self.owner[][0]
def wrong(anchor:List[Int]):
    var local:List[Int]=[1]
    var expected=pair_with(Above(Pointer(to=anchor)),range(3))
    var actual=pair_with(Above(Pointer(to=local)),range(3))
    expected=actual^
def main():pass
