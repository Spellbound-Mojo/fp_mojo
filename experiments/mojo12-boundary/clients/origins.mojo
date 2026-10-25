from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct SliceFault(Movable):
    var code: Int
def check(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def source() {view} -> View: return view
    def failed() raises View {view} -> Int: raise view
    var result = attempt(source)
    assert_equal(Pointer(to=result._ok().value[0]) == Pointer(to=owner[0]), True)
    var error = Capture[View].run(failed)
    assert_equal(Pointer(to=error._err().value[1]) == Pointer(to=owner[1]), True)
    def transform(var value: Int) {view} -> View: return view
    var values = piped(List[Int]([1, 2])).map(transform).get()
    assert_equal(Pointer(to=values[1][0]) == Pointer(to=owner[0]), True)
def main() raises:
    var owner: List[Int] = [7, 11]
    check(owner)
