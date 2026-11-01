# error: no matching method in call to 'pair_with'
# error: cannot be converted from 'def expansion_project(var x: ExpansionOwned)
from fp.functions import pipeline
@fieldwise_init
struct ExpansionOwned(Movable):
    var value: Int
def expansion_project(var x: ExpansionOwned) -> Int: return x.value
def main():
    var values: List[ExpansionOwned] = [ExpansionOwned(1)]
    _ = pipeline(values^).pair_with(expansion_project).get()
