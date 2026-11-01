"""Eager scans preserve explicit Never through native binary invocation."""
from fp.control import scan, ScanLengthError
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct ScanNeverToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def step(var carry: Int, var item: Int) raises Never -> Tuple[Int, Int]:
    return (carry + item, item)

def forward[A: Movable & Deinitable, X: Movable & Deinitable,
            Y: Movable & Deinitable, R: Movable & Deinitable,
            F: def(var A, var X) raises Never -> R](
    function: F, var initial: A, var values: List[X]
) raises ScanLengthError -> Tuple[A, List[Y]] where R == Tuple[A, Y]:
    return scan[Y=Y, E=Never](function, initial^, values^)

def exercise(drops: ArcPointer[Int]) raises:
    var owner = ScanNeverToken(10, drops)
    var calls = 0
    def captured(var carry: Int, var item: ScanNeverToken) raises Never {var owner^, mut calls} -> Tuple[Int, Int]:
        calls += 1
        return (carry + item.value, item.value + owner.value)
    var inputs: List[ScanNeverToken] = [ScanNeverToken(1, drops), ScanNeverToken(2, drops)]
    var first = forward(captured, 0, inputs^)
    assert_equal(first[0], 3)
    assert_equal(first[1], [11, 12])
    assert_equal(drops[], 2)
    var second = scan[E=Never](captured, 0, List[ScanNeverToken]())
    assert_equal(second[1], List[Int]())
    var last: List[ScanNeverToken] = [ScanNeverToken(3, drops)]
    var third = scan(captured, 0, last^)
    assert_equal(third[1], [13])
    assert_equal(calls, 3)

def main() raises:
    var ordinary = scan(step, 0, range(3))
    assert_equal(ordinary[0], 3)
    var explicit = scan[E=Never](step, 0, range(3))
    assert_equal(explicit[0], 3)
    var drops = ArcPointer(0)
    exercise(drops)
    assert_equal(drops[], 4)
