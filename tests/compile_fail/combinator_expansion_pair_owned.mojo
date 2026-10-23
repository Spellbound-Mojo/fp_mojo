# error: no matching method in call to 'pair_with'
from fp.functions import piped
@fieldwise_init
struct ExpansionOwned(Movable):
    var value: Int
def expansion_project(var x: ExpansionOwned) -> Int: return x.value
def main():
    var values: List[ExpansionOwned] = [ExpansionOwned(1)]
    _ = piped(values^).pair_with(expansion_project).get()
