# error: no matching method in call to 'traverse_tap'
from fp.functions import pipeline
from fp.algebra import OptionalFamily
from fp.callables import BorrowOnceCallable
@fieldwise_init
struct TTOnce(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Optional[Int]
    def invoke_once(deinit self, ref value: Int) raises Never capturing -> Optional[Int]: return Optional(value)
def main():
    var values: List[Int] = [1, 2]
    _ = pipeline(values^).traverse_tap[OptionalFamily](TTOnce())
