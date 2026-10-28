# error: mut_ref requires a repeatable library callable
from fp.callables import mut_ref, MutableRef, MutableUnary, OnceUnary, OnceBinary, OnceThunk, BorrowOnceCallable, UnaryContract
from fp.iteration import iterated
def main():
    var value=7
    _=mut_ref(value)
