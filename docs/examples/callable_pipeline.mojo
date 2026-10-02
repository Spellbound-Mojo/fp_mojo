"""Immediate pipeline of plain functions over a consumed list and a terminal fold."""
from fp.functions import pipe
from fp.iteration import filter, collect_list
from fp.iteration import fold_left
from std.testing import assert_equal

def nonnegative(value: Int) -> Bool: return value >= 0
def plus(var total: Int, var value: Int) -> Int: return total + value

def accepted(var values: List[Int]) -> List[Int]:
    return collect_list(filter(nonnegative, values^))

def total(var values: List[Int]) -> Int:
    return fold_left(plus, 0, values^)

def receipt(var value: Int) -> String: return "total=" + String(value)

@fieldwise_init
struct ReceiptFailure(Movable):
    var invalid_total: Int

def checked(var value: Int) raises ReceiptFailure -> Int:
    if value < 0: raise ReceiptFailure(value)
    return value

def main() raises:
    var values: List[Int] = [3, -2, 7, 0]
    var output = pipe(values^, accepted, total, receipt)
    assert_equal(output, "total=10")
    print(output)
    var invalid = 0
    try: _ = pipe(-4, checked, receipt)
    except error: invalid = error.invalid_total
    assert_equal(invalid, -4)
