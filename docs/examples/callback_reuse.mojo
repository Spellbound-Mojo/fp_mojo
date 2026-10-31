"""Reuse the same pricing callbacks in eager and lazy operations."""
from fp.functions import partial, pipeline
from fp.iteration import iterated


def multiply(unit_price: Int, quantity: Int) -> Int: return unit_price * quantity
def below(limit: Int, price: Int) -> Bool: return price < limit


def main():
    var price = partial(multiply, 3)
    var affordable = partial(below, 10)
    var pending = iterated(range(1, 5)).map(price).filter(affordable)
    print("eager:", pipeline[List[Int]]([1, 2, 4]).map(price).filter(affordable).get())
    print("lazy:", pending^.collect_list())
    print("total:", iterated(range(1, 4)).sum_by(price))
    var owned = iterated(range(1, 3)).map(price^)
    print("moved:", owned^.collect_list())
