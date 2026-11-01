# error: use of uninitialized value
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
@fieldwise_init
struct TXRejectedReuse(Movable):
    var value: Int
def check(value: TXRejectedReuse) -> Optional[Bool]: return Optional(True)
def main():
    var xs = List[TXRejectedReuse]()
    xs.append(TXRejectedReuse(1))
    _ = pipeline(xs^).filter_effect[OptionalFamily](check)
    print(len(xs))
