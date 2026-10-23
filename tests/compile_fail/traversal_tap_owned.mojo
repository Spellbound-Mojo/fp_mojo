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
    _ = piped(owners^).traverse_tap[OptionalFamily](consume)
