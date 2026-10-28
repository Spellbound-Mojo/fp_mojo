# error: no matching method
from fp.data import ok
from fp.functions import pipeline
from fp.callables import BorrowCallable

@fieldwise_init
struct Handler[X: Movable & Deinitable](BorrowCallable, ImplicitlyCopyable):
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = Self.X
    def invoke(self, ref value: Int) raises Self.X capturing -> Int:
        return value

def main():
    _ = pipeline(ok[Int](1)).fold(Handler[Int](), Handler[String]())
