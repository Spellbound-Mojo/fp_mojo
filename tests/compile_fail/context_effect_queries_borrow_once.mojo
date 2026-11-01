# error: no matching method
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.callables import BorrowOnceCallable
@fieldwise_init
struct Callback(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke_once(deinit self, ref value: Int) capturing -> Self.Result: return Optional(True)
def main(): _ = pipeline(List[Int]([1,2])).find_effect[OptionalFamily](Callback()).get()
