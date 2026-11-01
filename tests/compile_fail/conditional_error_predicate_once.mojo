# ResultT over ListFamily evaluates per element, so once callbacks are rejected.
# error: no matching method in call to 'recover_if'
# error: violated constraint
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
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
    _ = pipeline[L](fail[L, Int](String("bad"))).recover_if(CEOncePredicate(), restore).get()
