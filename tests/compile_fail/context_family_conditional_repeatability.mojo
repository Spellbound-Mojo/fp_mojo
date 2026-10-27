# error: no matching method in call to 'recover_if'
from fp.functions import pipeline
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.callables import BorrowOnceCallable, OnceUnary
@fieldwise_init
struct Predicate(BorrowOnceCallable):
    comptime Payload = String
    comptime Result = Bool
    def invoke_once(deinit self, error: String) -> Bool: return True
@fieldwise_init
struct Handler(OnceUnary):
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var error: String) -> Int: return 1
def main():
    comptime I = ResultT[ListFamily,String]
    _ = pipeline[I](I.fail[Int](String("x"))).recover_if(Predicate(),Handler()).get()
