# error: constraint
from fp.data import Result, Ok
from fp.callables import OnceThunk
@fieldwise_init
struct EFViewFactory[o: ImmOrigin](OnceThunk):
    var view: Span[Int,Self.o]
    comptime Out = Result[Span[Int,Self.o],String]
    def call_once(deinit self) -> Self.Out: return Ok(self.view)
def mismatch(left: List[Int],right: List[Int]):
    _ = Result[Bool,String](Ok(True)).if_effect(EFViewFactory(Span(left)),EFViewFactory(Span(right)))
def main(): mismatch([1],[2])
