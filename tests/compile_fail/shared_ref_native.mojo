# error: shared_ref requires a shared library callable
from fp.callables import shared_ref,SharedRef,Unary,UnaryContract,MutableUnary,OnceUnary,MutableBinary,OnceBinary,MutableThunk,OnceThunk,BorrowMutableCallable,BorrowOnceCallable
def native(value:Int)->Int:return value
def main():
    _=shared_ref(native)
