from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct ContextOriginsSliceFault(Movable):
    var code: Int
def check(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def source() {view} -> View: return view
    def failed() raises View {view} -> Int: raise view
    var result = Capture[Never]().run(source)
    assert_equal(Pointer(to=result._ok().value[0]) == Pointer(to=owner[0]), True)
    var error = Capture[View]().run(failed)
    assert_equal(Pointer(to=error._err().value[1]) == Pointer(to=owner[1]), True)
    def transform(var value: Int) {view} -> View: return view
    var values = piped(List[Int]([1, 2])).map(transform).get()
    assert_equal(Pointer(to=values[1][0]) == Pointer(to=owner[0]), True)
    def continue_with_view(var value: Int) {view} -> Result[View, View]:
        return Ok(view)
    var chained = piped(Result[Int, View](Ok(1))).flat_map(continue_with_view).get()
    assert_equal(Pointer(to=chained._ok().value[0]) == Pointer(to=owner[0]), True)
    var skipped = piped(Result[Int, View](Err(view))).flat_map(continue_with_view).get()
    assert_equal(Pointer(to=skipped._err().value[0]) == Pointer(to=owner[0]), True)
def main() raises:
    var owner: List[Int] = [7, 11]
    check(owner)
