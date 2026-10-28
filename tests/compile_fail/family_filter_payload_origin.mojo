# error: cannot implicitly convert
from fp.callables import BorrowMutableCallable
from fp.functions import pipeline
@fieldwise_init
struct Keep[o: ImmOrigin](BorrowMutableCallable):
    comptime Payload = Span[Int, Self.o]
    comptime Result = Bool
    def invoke_mut(mut self, ref value: Self.Payload) -> Bool: return True

def wrong[o: ImmOrigin](ref[o] source: List[Int]) -> List[Span[Int, o]]:
    var local: List[Int] = [1, 2]
    comptime View = Span[Int, ImmOrigin(origin_of(local))]
    var values: List[View] = [Span(local)]
    return pipeline(values^).filter(Keep[ImmOrigin(origin_of(local))]()).get()
def main(): pass
