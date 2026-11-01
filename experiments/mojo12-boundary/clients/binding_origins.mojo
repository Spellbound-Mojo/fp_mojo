from fp._binding_architecture import Capture
from fp.data import Result
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct Fault(Movable):
    var code: Int

def identity[T: Movable & Deinitable](var value: T) -> T: return value^
def fail[T: Movable & Deinitable](var value: T) raises T -> Int: raise value^
def check(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var result = Capture[Never].consuming(identity[View]).run(view)
    comptime assert type_of(result) == Result[View, Never]
    assert_equal(Pointer(to=result._ok().value[0]) == Pointer(to=owner[0]), True)
    var error = Capture[View].consuming(fail[View]).run(view)
    assert_equal(Pointer(to=error._err().value[1]) == Pointer(to=owner[1]), True)
    def mutable(mut state: Int) raises View {view} -> View:
        state += 1
        if state > 1: raise view
        return view
    var state = 0
    var callback = Capture[View].mutating(mutable)
    var a = callback.run(state)
    assert_equal(Pointer(to=a._ok().value[0]) == Pointer(to=owner[0]), True)
    var b = callback.run(state)
    assert_equal(Pointer(to=b._err().value[1]) == Pointer(to=owner[1]), True)
def main() raises:
    var owner: List[Int] = [7, 11]
    check(owner)
