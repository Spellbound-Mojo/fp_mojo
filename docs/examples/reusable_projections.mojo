"""Reuse one projection in eager reductions and lazy iterator terminals."""
from fp.functions import partial, pipeline
from fp.iteration import iterated, sum_by


def price(unit_price: Int, quantity: Int) -> Int:
    return unit_price * quantity


def main():
    var cost = partial(price, 3)
    print("direct total:", sum_by(cost, range(1, 4)))
    print("iterator total:", iterated(range(1, 4)).sum_by(cost))
    print("pipeline total:", pipeline[Int]([1, 2, 3]).sum_by(cost).get())
    print("largest quantity:", iterated(range(1, 4)).max_by(cost).value())
