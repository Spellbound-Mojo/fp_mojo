# error: constraint
from fp.iteration import find_map_effect
from fp.algebra import OptionalFamily, StringMonoid
from fp.callables import BorrowCallable, Unary
@fieldwise_init
struct Bad[o:ImmOrigin](Unary):
    var error:Span[Int,Self.o]
    comptime Arg=Int
    comptime Out=Optional[Optional[Int]]
    comptime Error=Span[Int,Self.o]
    def call(self,var value:Int) raises Self.Error ->Self.Out:
        raise self.error
def mismatch(left:List[Int],right:List[Int]):
    try: _=find_map_effect[OptionalFamily,X=Span[Int,origin_of(right)]](Bad(Span(left)),range(3))
    except:pass
def main():mismatch([1],[2])
