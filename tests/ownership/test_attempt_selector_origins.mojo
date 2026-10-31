from fp.data import Capture, Result, raise_on_err
from std.testing import assert_equal

def identity[V: Movable & Deinitable](var value: V) -> V:
    return value^

def fail[V: Movable & Deinitable](var value: V) raises V -> Int:
    raise value^

def check(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var result = Capture.take(view).run(identity[View])
    comptime assert type_of(result) == Result[View, Never]
    var returned = raise_on_err(result^)
    assert_equal(Pointer(to=returned[0]) == Pointer(to=owner[0]), True)
    var failed = Capture.take(view).run(fail[View])
    comptime assert type_of(failed) == Result[Int, View]
    var seen = False
    try: _ = raise_on_err(failed^)
    except error:
        seen = True
        assert_equal(Pointer(to=error[0]) == Pointer(to=owner[0]), True)
    assert_equal(seen, True)

def main() raises:
    var owner: List[Int] = [7, 11]
    check(owner)
