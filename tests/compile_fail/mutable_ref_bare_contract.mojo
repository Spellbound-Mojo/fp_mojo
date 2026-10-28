# error: mut_ref requires a repeatable library callable
from fp.callables import mut_ref, MutableRef, MutableUnary, OnceUnary, OnceBinary, OnceThunk, BorrowOnceCallable, UnaryContract
from fp.iteration import iterated
struct Bare(UnaryContract):
    comptime Arg=Int
    comptime Out=Int
    def __init__(out self):pass
def main():
    var callback=Bare()
    _=mut_ref(callback)
