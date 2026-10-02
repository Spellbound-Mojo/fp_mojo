"""Generic terminal wrappers retain the callback's exact typed error."""
from fp.iteration import fold_left
from fp.iteration import find
from std.iter import Iterator, iter
from std.testing import assert_equal


def folded[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator,
           E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](
    step: F, var initial: A, var source: I
) raises E -> A where I.Element == T:
    return fold_left[E=E](step, initial^, source^)


def forwarded[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator,
              E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](
    step: F, var initial: A, var source: I
) raises E -> A where I.Element == T:
    return folded[E=E](step, initial^, source^)


@fieldwise_init
struct InvalidEntry(Movable):
    var value: Int


def main() raises:
    var calls = 0
    def append(var text: String, var value: Int) raises InvalidEntry {mut calls} -> String:
        calls += 1
        if value < 0: raise InvalidEntry(value)
        return text + String(value)
    var result: String
    try: result = forwarded(append, String("entries:"), range(3))
    except: raise Error("unexpected entry error")
    assert_equal(result, "entries:012")
    assert_equal(calls, 3)
    var inputs: List[Int] = [4, -7, 9]
    var rejected = 0
    try: _ = forwarded(append, String("entries:"), iter(inputs^))
    except error:
        comptime assert type_of(error) == InvalidEntry
        rejected = error.value
    assert_equal(rejected, -7)
    assert_equal(calls, 5)
    def even(value: Int) -> Bool: return value % 2 == 0
    var first = find(even, range(3, 8))
    assert_equal(first.value(), 4)
    print(result, "; rejected:", rejected, "; first even:", first.value())
