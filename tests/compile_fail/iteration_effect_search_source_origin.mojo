# error: constraint
from fp.iteration import find_effect
from fp.algebra import OptionalFamily
def mismatch(left:List[Int],right:List[Int]):
    var xs=List[Span[Int,origin_of(left)]]()
    xs.append(Span(left))
    def wrong(value:Span[Int,origin_of(right)])->Optional[Bool]:return Optional(True)
    _=find_effect[OptionalFamily](xs^,wrong)
def main():mismatch([1],[2])
