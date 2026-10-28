# error: use of uninitialized value
from fp.data import ok
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable

@fieldwise_init
struct Handler(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = Never
    var offset: Int
    def invoke_once(deinit self, ref value: Int) capturing -> Int:
        return value + self.offset

def same(value: Int) -> Int: return value
def main():
    var handler = Handler(1)
    _ = pipeline(ok[Int](1)).fold(handler^, same)
    _ = pipeline(ok[Int](2)).fold(handler^, same)
