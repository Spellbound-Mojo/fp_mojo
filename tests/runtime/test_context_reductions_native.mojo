"""Stored thin pointers and native view origins retain their exact ABI."""
from fp.functions import pipeline
from fp.algebra import StringMonoid
from std.testing import assert_equal

def length(var value: String) -> Int: return value.byte_length()
def key(value: Int) -> Int: return -value
def text(var value: Int) -> String: return String(value)
def present(var value: Int) -> Optional[Int]: return Optional(value)
def never(var value: String) raises Never -> Int: return value.byte_length()
def fail(var value: String) raises Int -> Int: raise value.byte_length()

def views(owner: List[Int]) raises:
    comptime View=type_of(Span(owner))
    def select(var value: View) -> Optional[View]: return Optional(value)
    def size(value: View) -> Int: return len(value)
    var selected=pipeline(List[View]([Span(owner)])).find_map(select).get()
    assert_equal(selected.value().unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    var largest=pipeline(List[View]([Span(owner)])).max_by(size).get()
    assert_equal(largest.value().unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    var view=Span(owner)
    def project(var value: Int) {view} -> Optional[View]: return Optional(view)
    var from_capture=pipeline(range(1)).find_map(project).get()
    assert_equal(from_capture.value().unsafe_ptr()==Span(owner).unsafe_ptr(),True)
    def error(var value: Int) raises View {view} -> Int: raise view
    var caught=False
    try: _ = pipeline(range(1)).raising[View]().sum_by(error).get()
    except failure: caught=failure.unsafe_ptr()==Span(owner).unsafe_ptr()
    assert_equal(caught,True)

def main() raises:
    var count: def(var String) thin -> Int=length
    var rank: def(Int) thin -> Int=key
    var show: def(var Int) thin -> String=text
    var optional: def(var Int) thin -> Optional[Int]=present
    var literal: def(var String) raises Never thin -> Int=never
    var raising: def(var String) raises Int thin -> Int=fail
    assert_equal(pipeline(List[String](["a","bbb"])).sum_by(count).get(),4)
    assert_equal(pipeline(range(3)).max_by(rank).get().value(),0)
    assert_equal(pipeline(range(3)).min_by(rank).get().value(),2)
    assert_equal(pipeline(range(3)).fold_map[StringMonoid](show).get(),"012")
    assert_equal(pipeline(range(3)).find_map(optional).get().value(),0)
    assert_equal(pipeline(List[String](["aa"])).sum_by(literal).get(),2)
    assert_equal(pipeline(List[String](["aaa"])).raising[Int]().sum_by(literal).get(),3)
    var code=0
    try: _ = pipeline(List[String](["abcd"])).raising[Int]().sum_by(raising).get()
    except error: code=error
    assert_equal(code,4)
    views(List[Int]([1,2]))
