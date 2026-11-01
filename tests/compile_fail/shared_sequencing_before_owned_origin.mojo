# error: lacking evidence to prove correctness
from fp.data import Result,Ok,Err
from shared_sequencing_support import Maker,Projection
def wrong(left:List[Int],right:List[Int]) -> Result[Int,Span[Int,origin_of(left)]]:
    comptime L=Span[Int,origin_of(left)]
    comptime R=Span[Int,origin_of(right)]
    var factory=Maker(Result[Int,R](Err(Span(right))))
    _=Result[Int,L](Ok(1)).before(factory^)
    return Ok(1)
def main():
    var left:List[Int]=[1]
    var right:List[Int]=[2]
    _=wrong(left,right)
