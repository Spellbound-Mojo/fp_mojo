"""Native scans retain distinct carry/output origins and explicit bindings."""
from fp.control import scan
from fp.iteration import scan_map, iterated
from std.testing import assert_equal

def exercise(first: List[Int], second: List[Int]) raises:
    var initial = Span(first)
    var output = Span(second)
    comptime A = type_of(initial)
    comptime Y = type_of(output)
    def step(var carry: A, var item: Int) {output} -> Tuple[A, Y]:
        return (carry, output)
    def checked(var carry: A, var item: Int) raises Error {output} -> Tuple[A, Y]:
        if item < 0: raise Error("negative item")
        return (carry, output)
    var result = scan[2, -1](step, initial, range(2))
    assert_equal(Pointer(to=result[0][0]) == Pointer(to=first[0]), True)
    assert_equal(Pointer(to=result[1][1][0]) == Pointer(to=second[0]), True)
    try:
        var explicit = scan[Y=Y](checked, initial, range(2))
        debug_assert[assert_mode="safe"](Pointer(to=explicit[1][0][0]) == Pointer(to=second[0]))
    except: raise Error("unexpected scan error")
    var lazy = scan_map[type_of(step)](step, initial, range(2))
    assert_equal(Pointer(to=next(lazy)[0]) == Pointer(to=second[0]), True)
    var fluent = iterated(range(2)).scan_map[Y=Y](step, initial)
    assert_equal(Pointer(to=next(fluent)[0]) == Pointer(to=second[0]), True)
    var caught = False
    try: _ = scan(checked, initial, range(-1, 0))
    except: caught = True
    assert_equal(caught, True)

def main() raises:
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    exercise(first, second)
