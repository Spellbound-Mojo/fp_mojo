# error: shared_ref requires a shared library callable
from fp.callables import shared_ref
from shared_ref_support import ThunkMut
def main():
    var bad=ThunkMut()
    _=shared_ref(bad)
