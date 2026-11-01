# error: constraint
from fp.iteration import fold_map_effect
from fp.algebra import OptionalFamily, StringMonoid
from fp.callables import BorrowCallable, Unary
@fieldwise_init
struct Bad[o:ImmOrigin](Unary):
    var error:Span[Int,Self.o]
    comptime Arg=Int
    comptime Out=Optional[String]
    comptime Error=Span[Int,Self.o]
    def call(self,var value:Int) raises Self.Error ->Self.Out:
        raise self.error
def mismatch(left:List[Int],right:List[Int]):
    try: _=fold_map_effect[StringMonoid, OptionalFamily, X=Span[Int,origin_of(right)]](range(3),Bad(Span(left)))
    except:pass
def main():mismatch([1],[2])
