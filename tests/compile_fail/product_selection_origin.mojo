# error: cannot implicitly convert
from fp.functions import pipeline
def wrong[a: ImmOrigin,b: ImmOrigin](ref[a] first: Int,ref[b] second: Int) -> Optional[Pointer[Int,a]]:
    return pipeline(Optional(Pointer(to=first))).product_r(Optional(Pointer(to=second))).get()
def main(): pass
