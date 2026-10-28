# error: mut_ref requires a repeatable library callable
from fp.callables import mut_ref, MutableRef, MutableUnary, OnceUnary, OnceBinary, OnceThunk, BorrowOnceCallable, UnaryContract
from fp.iteration import iterated
struct Only(OnceThunk):
    comptime Out=Int
    def __init__(out self):pass
    def call_once(deinit self)->Int:return 1
def main():
    var callback=Only()
    _=mut_ref(callback)
