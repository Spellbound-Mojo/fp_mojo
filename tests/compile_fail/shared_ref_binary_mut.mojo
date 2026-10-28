# error: shared_ref requires a shared library callable
from fp.callables import shared_ref
from shared_ref_support import BinaryMut
def main():
    var bad=BinaryMut()
    _=shared_ref(bad)
