# error: constraint
from fp.data import Result,Ok
from fp.functions import piped
from fp.algebra import ListMonoid

def bad(left:List[Int],right:List[Int]):
    comptime L=Span[Int,origin_of(left)]
    comptime R=Span[Int,origin_of(right)]
    def validate(value:Int)->Result[Int,List[R]]:return Ok(value)
    _=piped(List[Int]([1,2])).par_traverse[ListMonoid[L]](validate)
def main():bad([1],[2])
