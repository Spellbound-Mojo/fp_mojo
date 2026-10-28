# error: shared_ref requires a shared library callable
from fp.callables import shared_ref,SharedRef,Unary,UnaryContract,MutableUnary,OnceUnary,MutableBinary,OnceBinary,MutableThunk,OnceThunk,BorrowMutableCallable,BorrowOnceCallable
def main():
    var value=7
    _=shared_ref(Pointer(to=value))
