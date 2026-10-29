# error: no matching
from fp.iteration import iterated
from fp.callables import BorrowCallable
@fieldwise_init
struct Wrong(BorrowCallable):
    comptime Payload = String
    comptime Result = Optional[Bool]
    def invoke(self, value: String) -> Self.Result: return Optional(value.byte_length())
def main():
    _ = iterated(List[Int]([1])).filter_effect(Wrong())
