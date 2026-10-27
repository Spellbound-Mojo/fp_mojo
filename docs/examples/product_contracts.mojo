from fp.algebra import ProductContract, Applicative, OptionalFamily, product
from std.testing import assert_equal

def pair[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](
    var left: V, var right: W
) raises ProductContract[I, V, W].Error -> ProductContract[I, V, W].Out where ProductContract[I, V, W].Compatible:
    return product[I](left^, right^)

def main() raises:
    var result = pair[OptionalFamily](Optional(3), Optional(String("four")))
    assert_equal(result.value()[0], 3)
    assert_equal(result.value()[1], "four")
    print("paired:", result.value()[0], result.value()[1])
