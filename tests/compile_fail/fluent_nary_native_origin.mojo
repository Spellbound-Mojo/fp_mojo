# error: constraint
from fp.functions import piped
def bad(left:List[Int],right:List[Int]):
    comptime View=Span[Int,origin_of(left)]
    def pick(a:Int,var b:View,c:Int) -> Int: return b[0]
    _=piped(Optional(1)).map_n((Optional(Span(right)),Optional(3)),pick)
def main(): bad([1],[2])
