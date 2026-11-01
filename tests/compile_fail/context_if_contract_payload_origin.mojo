# error: invalid call to 'forward': lacking evidence to prove correctness
from context_if_contract_support import forward, Factory, Once, StringFactory, ErrorFactory, PointerFactory
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok

def mismatch[a: ImmOrigin,b: ImmOrigin](ref[a] left: Int,ref[b] right: Int):
    _ = forward[OptionalFamily](PointerFactory[a](Pointer(to=left)), PointerFactory[b](Pointer(to=right)), Optional(True))
def main(): pass
