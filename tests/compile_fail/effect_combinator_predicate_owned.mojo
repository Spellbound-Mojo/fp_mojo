# Mojo 1.2: bind F before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'F' cannot be converted
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
    _ = iterated(xs^).all_effect[OptionalFamily, F=type_of(wrong)](wrong)
