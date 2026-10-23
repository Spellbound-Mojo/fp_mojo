# error: does not conform to trait 'Copyable & Deinitable'
from fp.iteration import iterated
@fieldwise_init
struct ExpansionOwned(Movable):
    var value: Int
def main():
    _ = iterated(range(3)).fill(ExpansionOwned(1))
