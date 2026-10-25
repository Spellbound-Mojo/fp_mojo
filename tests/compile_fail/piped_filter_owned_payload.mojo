# Mojo 1.2: bind F before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'F' cannot be converted
# error: no matching method in call to 'filter'
from fp.functions import piped

def select(var x: Int) -> Bool: return x > 0
def main():
    var xs: List[Int] = [1, 2]
    _ = piped(xs^).filter[F=type_of(select)](select).get()
