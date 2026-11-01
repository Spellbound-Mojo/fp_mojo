# error: no matching method
# error: candidate not viable: violated constraint
from fp.functions import pipeline
from fp.effects import Reader, ResultT
from fp.callables import BorrowCallable, Unary
@fieldwise_init
struct Predicate(BorrowCallable):
    comptime Payload = String
    comptime Result = Bool
    comptime Failure = String
    def invoke(self, error: String) raises String -> Bool: raise String("predicate")
@fieldwise_init
struct Handler(Unary):
    comptime Arg = String
    comptime Out = Int
    comptime Error = Int
    def call(self, var error: String) raises Int -> Int: raise 1
def main():
    comptime I = ResultT[Reader[Int],String]
    _ = pipeline[I](I.fail[Int](String("x"))).recover_if(Predicate(),Handler()).get()
