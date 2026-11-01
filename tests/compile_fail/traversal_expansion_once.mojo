# error: no matching method in call to 'filter_effect'
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
from fp.callables import BorrowOnceCallable
@fieldwise_init
struct TXRejectedOnce(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Optional[Bool]
    def invoke_once(deinit self, ref value: Int) raises Never capturing -> Optional[Bool]: return Optional(True)
def main():
    var xs: List[Int] = [1, 2]
    _ = pipeline(xs^).filter_effect[OptionalFamily](TXRejectedOnce())
