# error: shared_ref requires a shared library callable
from fp.callables import shared_ref
from shared_ref_support import BorrowMut
def main():
    var bad=BorrowMut()
    _=shared_ref(bad)
