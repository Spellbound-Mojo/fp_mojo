# ResultT over ListFamily evaluates per element, so once callbacks are rejected.
# error: no matching method in call to 'recover_if'
from fp.algebra import ResultFamily, OptionalFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import OnceUnary, BorrowOnceCallable
from fp.data import Result, Ok, Err
@fieldwise_init
struct CEOnceHandler(OnceUnary):
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var error: String) -> Int: return 0
def yes(error: String) -> Bool: return True
def main():
    comptime L = ResultT[ListFamily, String]
    _ = pipeline[L](fail[L, Int](String("bad"))).recover_if(yes, CEOnceHandler()).get()
