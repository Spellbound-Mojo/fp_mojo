# error: shared_ref requires a shared library callable
from fp.callables import shared_ref
from shared_ref_support import BinaryOnce
def main():
    var bad=BinaryOnce()
    _=shared_ref(bad)
