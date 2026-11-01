"""Generic native pointers preserve exact types and borrowed error origins."""
from fp.functions import pipeline
from std.testing import assert_equal

def forward[A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable](function: def(var A) raises E thin -> R, var source: Optional[A]) raises E -> Optional[R]:
    return pipeline(source^).raising[E]().map(function).get()

def increment(var value: Int) raises Never -> Int: return value + 1

def forward_never[E: Movable & Deinitable](function: def(var Int) raises Never thin -> Int) -> Optional[Int]:
    return pipeline(Optional(1)).raising[E]().map(function).get()

def check(values: List[Int]) raises:
    comptime View = type_of(Span(values))
    def fail(var view: View) raises View -> Int: raise view
    var pointer: def(var View) raises View thin -> Int = fail
    var code = 0
    try: _ = forward(pointer, Optional(Span(values)))
    except error: code = error[0]
    assert_equal(code, 7)
    def first(var view: View) -> View: return view
    var result_pointer: def(var View) thin -> View = first
    var result = pipeline(Optional(Span(values))).map(result_pointer).get()
    assert_equal(result.value()[0], 7)

def main() raises:
    var pure: def(var Int) raises Never thin -> Int = increment
    assert_equal(forward(pure, Optional(1)).value(), 2)
    assert_equal(forward_never[String](pure).value(), 2)
    assert_equal(forward_never[Never](pure).value(), 2)
    check(List[Int]([7, 8]))
