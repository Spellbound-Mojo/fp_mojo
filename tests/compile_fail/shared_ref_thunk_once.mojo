# error: shared_ref requires a shared library callable
from fp.callables import shared_ref
from shared_ref_support import ThunkOnce
def main():
    var bad=ThunkOnce()
    _=shared_ref(bad)
