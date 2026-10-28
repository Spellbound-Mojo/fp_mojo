# error: lacking evidence to prove correctness
from fp.data import Result,Ok
from shared_sequencing_support import Maker
def wrong(left:List[Int],right:List[Int]):
    comptime L=Span[Int,origin_of(left)]
    comptime R=Span[Int,origin_of(right)]
    var factory=Maker(Result[Int,R](Ok(7)))
    _=Result[Int,L](Ok(1)).followed_by(factory)
def main():wrong([1],[2])
