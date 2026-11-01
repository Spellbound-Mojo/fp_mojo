# error: cannot implicitly convert
from fp.algebra import product_l, OptionalFamily
def wrong[a: ImmOrigin,b: ImmOrigin](ref[a] first: Int,ref[b] second: Int) -> Optional[Pointer[Int,b]]:
    return product_l[OptionalFamily](Optional(Pointer(to=first)),Optional(Pointer(to=second)))
def main(): pass
