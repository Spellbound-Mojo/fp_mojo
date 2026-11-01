# error: no matching method in call to 'traverse_tap'
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.callables import BorrowOnceCallable
@fieldwise_init
struct Once(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke_once(deinit self, ref value: Int) capturing -> Self.Result: return Optional(True)
def main(): _ = pipeline(List[Int]([1,2])).traverse_tap[OptionalFamily](Once()).get()
