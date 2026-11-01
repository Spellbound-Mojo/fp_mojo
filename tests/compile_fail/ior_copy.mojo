# error: Copyable
from fp.data import Ior, Both
@fieldwise_init
struct IOROwner(Movable):
    var value: Int
def main():
    var value: Ior[IOROwner, IOROwner] = Both(IOROwner(1), IOROwner(2))
    _ = value.copy()
