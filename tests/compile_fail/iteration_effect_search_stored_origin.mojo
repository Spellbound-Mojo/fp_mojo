# error: constraint
from fp.iteration import find_map_effect
from fp.algebra import ResultFamily
from fp.data import Result,Ok
def mismatch(left:List[Int],right:List[Int]):
    comptime L=Span[Int,origin_of(left)]
    comptime R=Span[Int,origin_of(right)]
    def wrong(var value:Int)->Result[Optional[Int],R]:return Ok(Optional(value))
    _=find_map_effect[ResultFamily[L]](range(3),wrong)
def main():mismatch([1],[2])
