# error: mut_ref requires a repeatable library callable
from fp.callables import mut_ref, MutableRef, MutableUnary, OnceUnary, OnceBinary, OnceThunk, BorrowOnceCallable, UnaryContract
from fp.iteration import iterated
struct Only(BorrowOnceCallable):
    comptime Payload=Int
    comptime Result=Bool
    def __init__(out self):pass
    def invoke_once(deinit self,ref value:Int)->Bool:return True
def main():
    var callback=Only()
    _=mut_ref(callback)
