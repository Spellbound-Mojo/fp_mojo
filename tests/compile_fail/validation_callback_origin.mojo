# error: constraint
from fp.data import Result,Ok

def bad(left:List[Int],right:List[Int]):
    comptime L=Span[Int,origin_of(left)]
    comptime R=Span[Int,origin_of(right)]
    def keep(var value:R,b:Int)->R:return value
    _=Result[L,List[String]](Ok(Span(left))).par_map_n((Result[Int,List[String]](Ok(1)),),keep)
def main():bad([1],[2])
