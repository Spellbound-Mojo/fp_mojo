# error: origin_of(local)
from fp.callables import BorrowMutableCallable
from fp.effects import Reader
from fp.functions import pipeline
@fieldwise_init
struct Inspect[o:ImmOrigin](BorrowMutableCallable):
    comptime Payload=Int
    comptime Result=Int
    var owner:Pointer[List[Int],Self.o]
    def invoke_mut(mut self,ref value:Int)->Int:return self.owner[][0]+value
def wrong(anchor:List[Int]):
    var local:List[Int]=[1]
    comptime R=Reader[Int]
    var expected=pipeline[R](R.pure(1)).tap_each(Inspect(Pointer(to=anchor))).get()
    var actual=pipeline[R](R.pure(1)).tap_each(Inspect(Pointer(to=local))).get()
    expected=actual^
def main():pass
