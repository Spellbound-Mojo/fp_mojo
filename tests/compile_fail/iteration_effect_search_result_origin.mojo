# error: origin_of(local)
from fp.iteration import find_map_effect
from fp.algebra import OptionalFamily
def mismatch(anchor:List[Int]):
    var local:List[Int]=[1]
    comptime View=Span[Int,origin_of(local)]
    def wrong(var value:Int)->Optional[Optional[View]]:return Optional(Optional(Span(local)))
    var escaped:Optional[Optional[Span[Int,origin_of(anchor)]]]=find_map_effect[OptionalFamily](range(3),wrong)
    _=escaped^
def main():mismatch([1])
