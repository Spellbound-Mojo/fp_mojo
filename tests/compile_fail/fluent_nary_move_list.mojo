# error: Copyable
from fp.functions import pipeline
@fieldwise_init
struct NaryOwned(Movable):
    var value:Int
def main():
    var a:List[NaryOwned]=[NaryOwned(1)]
    var b:List[NaryOwned]=[NaryOwned(2)]
    _=pipeline(a^).product_n((b^,))
