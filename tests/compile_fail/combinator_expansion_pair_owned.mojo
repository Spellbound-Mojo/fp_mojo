# Mojo 1.2: bind F before checking the invalid native signature.
# Removing this hint reproduces a compiler crash; see native-boundaries.md.
# error: value passed to 'F' cannot be converted
# error: no matching method in call to 'pair_with'
from fp.functions import piped
@fieldwise_init
struct ExpansionOwned(Movable):
    var value: Int
def expansion_project(var x: ExpansionOwned) -> Int: return x.value
def main():
    var values: List[ExpansionOwned] = [ExpansionOwned(1)]
    _ = piped(values^).pair_with[F=type_of(expansion_project)](expansion_project).get()
