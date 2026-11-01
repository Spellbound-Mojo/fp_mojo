# error: use of uninitialized value 'callback'
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
def main():
    var callback=Counter(0)
    var pending=iterated(range(3)).map(mut_ref(callback))
    var moved=callback^
    print(moved.calls)
    print(pending^.to_list())
