from fp.data import Capture
from fp.data import Result
from std.testing import assert_equal

def callback[V: Copyable & Deinitable](mut state: Int, var value: V, /, var **options: V) raises V -> V:
    state += len(options)
    if state > 1: raise value^
    return value^

def check(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var state = 0
    var pending = Capture[View].mutable(state).take(view).kwargs(extra=view)
    var result = pending^.run(callback[View])
    comptime assert type_of(result) == Result[View, View]
    assert_equal(Pointer(to=result._ok().value[0]) == Pointer(to=owner[0]), True)
    var error = Capture[View].mutable(state).take(view).kwargs(extra=view).run(callback[View])
    assert_equal(Pointer(to=error._err().value[1]) == Pointer(to=owner[1]), True)

def main() raises:
    var owner: List[Int] = [7, 11]
    check(owner)
