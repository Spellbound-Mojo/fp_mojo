# error: Copyable
from fp.functions import piped
@fieldwise_init
struct NaryOwned(Movable):
    var value:Int
def main():
    var a:List[NaryOwned]=[NaryOwned(1)]
    var b:List[NaryOwned]=[NaryOwned(2)]
    _=piped(a^).product_n((b^,))
