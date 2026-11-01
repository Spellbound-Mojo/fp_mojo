# error: no matching
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable
@fieldwise_init
struct Once(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke_once(deinit self, ref value: Int) capturing -> Self.Result: return Optional(True)
def main():
    _ = pipeline(List[Int]([1])).filter_effect(Once())
