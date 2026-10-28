# error: value passed to 'function' cannot be converted
from fp.callables import mut_ref, MutableRef, MutableUnary, OnceUnary, OnceBinary, OnceThunk, BorrowOnceCallable, UnaryContract
from fp.iteration import iterated
@fieldwise_init
struct Counter(MutableUnary):
    comptime Arg=Int
    comptime Out=Int
    var calls:Int
    def call_mut(mut self,var value:Int)->Int:
        self.calls+=1
        return value+self.calls
def wrong(callback:Counter):_=mut_ref(callback)
def main():pass
