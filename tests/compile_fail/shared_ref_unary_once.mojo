# error: shared_ref requires a shared library callable
from fp.callables import shared_ref
from shared_ref_support import UnaryOnce
def main():
    var bad=UnaryOnce()
    _=shared_ref(bad)
