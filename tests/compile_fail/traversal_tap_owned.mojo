# Mojo 1.2: bind F before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'F' cannot be converted
# error: no matching method
from fp.functions import piped
from fp.algebra import OptionalFamily
@fieldwise_init
struct TTOwner(Movable):
    var value: Int
def consume(var value: TTOwner) -> Optional[Int]: return Optional(value.value)
def main():
    var owners = List[TTOwner]()
    owners.append(TTOwner(1))
    _ = piped(owners^).traverse_tap[OptionalFamily, F=type_of(consume)](consume)
