# error: repeatable
from fp.algebra import ResultFamily, ListFamily, OptionalFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
@fieldwise_init
struct EOOnlyOnce(BorrowOnceCallable):
    comptime Payload = String
    comptime Result = Int
    def invoke_once(deinit self, ref error: String) raises Never capturing -> Int: return 0
def main():
    comptime F = ResultT[ListFamily, String]
    _ = piped(fail[F, Int](String())).tap_err[F](EOOnlyOnce()).get()
