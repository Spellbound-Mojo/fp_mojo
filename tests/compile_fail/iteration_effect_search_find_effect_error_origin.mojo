# error: constraint
from fp.iteration import find_effect
from fp.algebra import OptionalFamily, StringMonoid
from fp.callables import BorrowCallable, Unary
@fieldwise_init
struct Bad[o:ImmOrigin](BorrowCallable):
    var error:Span[Int,Self.o]
    comptime Payload=Int
    comptime Result=Optional[Bool]
    comptime Failure=Span[Int,Self.o]
    def invoke(self,ref value:Int) raises Self.Failure capturing ->Self.Result:
        raise self.error
def mismatch(left:List[Int],right:List[Int]):
    try: _=find_effect[OptionalFamily,X=Span[Int,origin_of(right)]](Bad(Span(left)),range(3))
    except:pass
def main():mismatch([1],[2])
