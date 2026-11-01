# error: shared_ref requires a shared library callable
from fp.callables import shared_ref
from shared_ref_support import Bare
def main():
    var bad=Bare()
    _=shared_ref(bad)
