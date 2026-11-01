# error: no matching method in call to 'filter_effect'
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ListFamily
@fieldwise_init
struct TXRejectedOwner(Movable):
    var value: Int
def choices(value: TXRejectedOwner) -> List[Bool]: return [False, True]
def main():
    var xs = List[TXRejectedOwner]()
    xs.append(TXRejectedOwner(1))
    _ = pipeline(xs^).filter_effect[ListFamily](choices)
