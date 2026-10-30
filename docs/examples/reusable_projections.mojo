"""Reuse projections in reductions and lazy Optional mapping."""
from fp.functions import partial, pipeline
from fp.iteration import iterated, sum_by


def price(unit_price: Int, quantity: Int) -> Int:
    return unit_price * quantity


def priced(unit_price: Int, quantity: Int) -> Optional[Int]:
    if quantity <= 0: return None
    return Optional(price(unit_price, quantity))


def main():
    var cost = partial(price, 3)
    print("direct total:", sum_by(range(1, 4), cost))
    print("iterator total:", iterated(range(1, 4)).sum_by(cost))
    print("pipeline total:", pipeline[Int]([1, 2, 3]).sum_by(cost).get())
    print("largest quantity:", iterated(range(1, 4)).max_by(cost).value())
    var quote = partial(priced, 3)
    print("available quotes:", iterated(range(-1, 3)).filter_map(quote).collect_list())
    print("quoted total:", iterated(range(1, 4)).filter_map(quote).sum())
