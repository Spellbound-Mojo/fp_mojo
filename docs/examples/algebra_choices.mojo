"""Choose mapping, applicative combination or monadic bind for optional orders."""
from fp.algebra import map, pure, flat_map, map2, ap, OptionalFamily, ListFamily
from fp.functions import partial
from std.testing import assert_equal


def subtotal(unit_price: Int, quantity: Int) -> Int:
    return unit_price * quantity


def in_stock(quantity: Int) -> Optional[Int]:
    return Optional(quantity) if 0 < quantity <= 5 else Optional[Int]()


def main() raises:
    var quantity = pure[OptionalFamily](3)
    var priced = map[OptionalFamily](partial(subtotal, 12), quantity)
    assert_equal(priced.value(), 36)
    print("mapped price:", priced.value())

    # Mapping a fallible computation keeps its Optional inside the outer one.
    var nested = map[OptionalFamily](in_stock, Optional(8))
    assert_equal(Bool(nested), True)
    assert_equal(Bool(nested.value()), False)
    var checked = flat_map[OptionalFamily](in_stock, Optional(8))
    assert_equal(Bool(checked), False)
    print("map: outer present =", Bool(nested), "; inner present =", Bool(nested.value()))
    print("flat_map: present =", Bool(checked))

    # Both inputs already exist; the combiner runs only when both are present.
    var combined = map2[OptionalFamily](partial(subtotal), Optional(12), Optional(3))
    assert_equal(combined.value(), 36)
    var missing = map2[OptionalFamily](partial(subtotal), Optional(12), Optional[Int]())
    assert_equal(Bool(missing), False)
    print("combined price:", combined.value(), "; missing quantity:", Bool(missing))

    # ap takes the function from its context as well as the argument.
    var pricing = Optional(partial(subtotal, 12))
    var applied = ap[OptionalFamily](pricing^, Optional(3))
    assert_equal(applied.value(), 36)
    print("applied price:", applied.value())

    # List's Applicative forms every pair, in left-major order.
    var prices: List[Int] = [10, 20]
    var quantities: List[Int] = [1, 2]
    var totals = map2[ListFamily](partial(subtotal), prices^, quantities^)
    var expected: List[Int] = [10, 20, 20, 40]
    assert_equal(totals, expected)
    print("list combinations:", totals[0], totals[1], totals[2], totals[3])
