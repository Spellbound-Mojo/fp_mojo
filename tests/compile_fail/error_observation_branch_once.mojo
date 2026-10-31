# ResultT over ListFamily observes each element, so a once observer is rejected.
# error: no matching method in call to 'tap_err'
# error: violated constraint
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
@fieldwise_init
struct EOOnlyOnce(BorrowOnceCallable):
    comptime Payload = String
    comptime Result = Int
    def invoke_once(deinit self, ref error: String) raises Never capturing -> Int: return 0
def main():
    comptime F = ResultT[ListFamily, String]
    _ = pipeline[F](fail[F, Int](String())).tap_err(EOOnlyOnce()).get()
