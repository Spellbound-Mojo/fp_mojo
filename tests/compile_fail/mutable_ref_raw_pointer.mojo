# error: mut_ref requires a repeatable library callable
from fp.callables import mut_ref, MutableRef, MutableUnary, OnceUnary, OnceBinary, OnceThunk, BorrowOnceCallable, UnaryContract
from fp.iteration import iterated
def native(var value:Int)->Int:return value
def main():
    var function:def(var Int) thin -> Int=native
    _=mut_ref(function)
