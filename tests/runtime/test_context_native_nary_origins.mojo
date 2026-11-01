"""Stored native signatures retain borrowed payload, result and raised-error origins."""
from fp.functions import pipeline
from std.testing import assert_equal

def check(values: List[Int]) raises:
    comptime View = type_of(Span(values))
    def first(var view: View, var count: Int, var text: String) -> View: return view
    var pointer: def(var View, var Int, var String) thin -> View = first
    var result = pipeline(Optional(Span(values))).map_n((Optional(2), Optional(String("x"))), pointer).get()
    assert_equal(result.value()[0], 7)
    def fail(var count: Int, var text: String, var view: View) raises View -> Int: raise view
    var raising: def(var Int, var String, var View) raises View thin -> Int = fail
    var code = 0
    try: _ = pipeline(Optional(1)).raising[View]().map_n((Optional(String("x")), Optional(Span(values))), raising).get()
    except error: code = error[0]
    assert_equal(code, 7)

def main() raises:
    check(List[Int]([7, 8]))
