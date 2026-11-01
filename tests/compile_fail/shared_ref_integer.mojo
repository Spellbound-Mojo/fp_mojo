# error: shared_ref requires a shared library callable
from fp.callables import shared_ref,SharedRef,Unary,UnaryContract,MutableUnary,OnceUnary,MutableBinary,OnceBinary,MutableThunk,OnceThunk,BorrowMutableCallable,BorrowOnceCallable
def main():
    _=shared_ref(7)
