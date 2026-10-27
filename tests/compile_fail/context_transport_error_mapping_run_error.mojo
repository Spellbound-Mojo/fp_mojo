# error: no matching method in call to 'map_err'
from fp.algebra import ResultFamily
from fp.callables import BorrowCallable
from fp.effects import ReaderT, action
from fp.data import Result
from fp.functions import pipeline
@fieldwise_init
struct Source(BorrowCallable,Defaultable):
    comptime Payload = Int
    comptime Result = Result[Int,String]
    comptime Failure = String
    def invoke(self,ref value: Int) raises String -> Self.Result: raise String("source")
def size(var error: String) raises Int -> Int: raise error.byte_length()
def main():
    comptime I = ReaderT[ResultFamily[String],Int]
    _ = pipeline[I](action[I,Int](Source())).raising[Int]().map_err(size)
