# error: origin_of
from fp.iteration import find_map_effect
from fp.effects import Reader,run
from fp.callables import Unary
@fieldwise_init
struct Project[o:ImmOrigin](Unary):
    var value:Span[Int,Self.o]
    comptime Arg=Int
    comptime Out=Reader[Int].Pure[Optional[Int]]
    def call(self,var value:Int)->Self.Out:return Reader[Int].pure(Optional(self.value[0]))
def mismatch(anchor:List[Int]):
    var local:List[Int]=[1]
    var expected=find_map_effect[Reader[Int]](Project(Span(anchor)),range(3))
    expected=find_map_effect[Reader[Int]](Project(Span(local)),range(3))
    _=run[Reader[Int]](expected^,0)
def main():mismatch([1])
