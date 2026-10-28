# error: origin_of(local)
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
def wrong[o:MutOrigin](ref[o] original:Counter)->MutableRef[Counter,o]:
    var local=Counter(0)
    return mut_ref(local)
def main():pass
