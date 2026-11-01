# error: shared_ref requires a shared library callable
from fp.callables import shared_ref
from shared_ref_support import BorrowOnce
def main():
    var bad=BorrowOnce()
    _=shared_ref(bad)
