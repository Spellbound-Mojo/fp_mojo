# error: repeatable
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
@fieldwise_init
struct CEOncePredicate(BorrowOnceCallable):
    comptime Payload = String
    comptime Result = Bool
    def invoke_once(deinit self, ref payload: String) raises Never capturing -> Bool: return True
def restore(var error: String) -> Int: return 0
def main():
    comptime L = ResultT[ListFamily, String]
    _ = piped(fail[L, Int](String("bad"))).recover_if[L](CEOncePredicate(), restore).get()
