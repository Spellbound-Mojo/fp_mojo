# Mojo 1.2: bind F before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'F' cannot be converted
# error: no matching method
from fp.functions import piped
from fp.algebra import OptionalFamily, ListFamily
def wrong(var value: String) -> Optional[Bool]: return Optional(True)
def main():
    var xs: List[String] = [String("one")]
    _ = piped(xs^).filter_effect[OptionalFamily, F=type_of(wrong)](wrong)
