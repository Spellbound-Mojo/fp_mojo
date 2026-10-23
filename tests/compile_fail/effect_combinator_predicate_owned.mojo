# error: no matching method
from fp.iteration import iterated
from fp.algebra import OptionalFamily
@fieldwise_init
struct EFBadValue(Movable):
    var text: String
def wrong(var x: EFBadValue) -> Optional[Bool]: return Optional(True)
def main():
    var xs = List[EFBadValue]()
    xs.append(EFBadValue("a"))
    _ = iterated(xs^).all_effect[OptionalFamily](wrong)
