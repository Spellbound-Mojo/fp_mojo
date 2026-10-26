"""Native thin signatures and borrowed payload/error origins survive composition."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal

def select(var value: Int) -> Optional[Optional[Int]]: return Optional(Optional(value))
def never_select(var value: Int) raises Never -> Optional[Optional[Int]]: return Optional(Optional(value))
def expand(var value: Int) -> Optional[List[Int]]: return Optional(List[Int]([value]))
def fail(var value: Int) raises Int -> Optional[List[Int]]: raise value
def string_select(var value: String) -> Optional[Optional[String]]: return Optional(Optional(value^))

def check_origins(owner: List[Int], errors: List[Int]) raises:
    comptime View = type_of(Span(owner))
    comptime Failure = type_of(Span(errors))
    var failure = Span(errors)
    def present(var value: View) -> Optional[Optional[View]]: return Optional(Optional(value))
    var selected = pipeline(List[View]([Span(owner)])).traverse_filter[OptionalFamily](present).get()
    assert_equal(selected.value()[0].unsafe_ptr() == Span(owner).unsafe_ptr(), True)
    def nested(var value: View) -> Optional[List[View]]: return Optional(List[View]([value]))
    var flattened = pipeline(List[View]([Span(owner)])).flat_traverse[OptionalFamily](nested).get()
    assert_equal(flattened.value()[0].unsafe_ptr() == Span(owner).unsafe_ptr(), True)
    var source = pipeline(Result[View,Failure](Err(failure))).traverse_void[OptionalFamily](present).get()
    assert_equal(source.value()._err().value.unsafe_ptr() == Span(errors).unsafe_ptr(), True)
    def reject(var value: View) {failure} -> Result[Optional[View],Failure]: return Err(failure)
    var stored = pipeline(List[View]([Span(owner)])).traverse_filter[ResultFamily[Failure]](reject).get()
    assert_equal(stored._err().value.unsafe_ptr() == Span(errors).unsafe_ptr(), True)
    def raise_view(var value: View) raises Failure {failure} -> Optional[Int]: raise failure
    var matched = False
    try: _ = pipeline(List[View]([Span(owner)])).raising[Failure]().traverse_void[OptionalFamily](raise_view).get()
    except error: matched = error.unsafe_ptr() == Span(errors).unsafe_ptr()
    assert_equal(matched, True)

def pure() -> Optional[List[Int]]:
    var function: def(var Int) raises Never thin -> Optional[Optional[Int]] = never_select
    return pipeline(List[Int]([1,2])).raising[Int]().traverse_filter[OptionalFamily](function).get()

def main() raises:
    assert_equal(pure().value(), List[Int]([1,2]))
    var mapper: def(var Int) thin -> Optional[Optional[Int]] = select
    assert_equal(pipeline(List[Int]([1,2])).traverse_filter[OptionalFamily](mapper).get().value(), List[Int]([1,2]))
    _ = pipeline(List[Int]([1,2])).traverse_void[OptionalFamily](mapper).get()
    var expanding: def(var Int) thin -> Optional[List[Int]] = expand
    assert_equal(pipeline(List[Int]([1,2])).flat_traverse[OptionalFamily](expanding).get().value(), List[Int]([1,2]))
    var strings: def(var String) thin -> Optional[Optional[String]] = string_select
    assert_equal(pipeline(List[String](["abc"])).traverse_filter[OptionalFamily](strings).get().value(), List[String](["abc"]))
    var failing: def(var Int) raises Int thin -> Optional[List[Int]] = fail
    var code = 0
    try: _ = pipeline(List[Int]([7])).raising[Int]().flat_traverse[OptionalFamily](failing).get()
    except error: code = error
    assert_equal(code, 7)
    check_origins(List[Int]([7,11]), List[Int]([13,17]))
