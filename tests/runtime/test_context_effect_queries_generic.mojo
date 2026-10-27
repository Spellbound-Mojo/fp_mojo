"""Generic forwarding uses ordinary calls and retains payload and error origins."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, StringMonoid
from fp.data import Result, Err
from std.testing import assert_equal

def forward_find[A: Movable & Deinitable, E: Movable & Deinitable, //,
                 F: def(A) raises E -> Optional[Bool]](ref function: F, var source: List[A]) raises E -> Optional[Optional[A]]:
    return pipeline(source^).raising[E]().find_effect(function).get()

def forward_map[A: Movable & Deinitable, B: Movable & Deinitable, E: Movable & Deinitable, //,
                F: def(var A) raises E -> Optional[Optional[B]]](ref function: F, var source: List[A]) raises E -> Optional[Optional[B]]:
    return pipeline(source^).raising[E]().find_map_effect(function).get()

def forward_fold[A: Movable & Deinitable, B: Movable & Deinitable, E: Movable & Deinitable, //,
                 F: def(var A, var B) raises E -> Optional[A]](ref function: F, var initial: A, var source: List[B]) raises E -> Optional[A]:
    return pipeline(source^).raising[E]().fold_effect(initial^).run(function).get()

def forward_monoid[A: Movable & Deinitable, E: Movable & Deinitable, //,
                   F: def(var A) raises E -> Optional[String]](ref function: F, var source: List[A]) raises E -> Optional[String]:
    return pipeline(source^).raising[E]().fold_map_effect[OptionalFamily, StringMonoid](function).get()

def origins(owner: List[Int], errors: List[Int]) raises:
    comptime View = type_of(Span(owner))
    comptime Failure = type_of(Span(errors))
    var failure = Span(errors)
    def accept(value: View) -> Optional[Bool]: return Optional(True)
    def project(var value: View) -> Optional[Optional[View]]: return Optional(Optional(value))
    var selected = forward_find(accept, List[View]([Span(owner)]))
    var mapped = forward_map(project, List[View]([Span(owner)]))
    assert_equal(selected.value().value().unsafe_ptr() == Span(owner).unsafe_ptr(), True)
    assert_equal(mapped.value().value().unsafe_ptr() == Span(owner).unsafe_ptr(), True)
    def reject(value: View) {failure} -> Result[Bool, Failure]: return Err(failure)
    var stored = pipeline(List[View]([Span(owner)])).find_effect(reject).get()
    assert_equal(stored._err().value.unsafe_ptr() == Span(errors).unsafe_ptr(), True)
    def raise_view(value: View) raises Failure {failure} -> Optional[Bool]: raise failure
    var matched = False
    try: _ = forward_find(raise_view, List[View]([Span(owner)]))
    except error: matched = error.unsafe_ptr() == Span(errors).unsafe_ptr()
    assert_equal(matched, True)

def main() raises:
    def choose(value: Int) raises Int -> Optional[Bool]:
        if value < 0: raise value
        return Optional(value == 2)
    def project(var value: Int) -> Optional[Optional[String]]: return Optional(Optional(String(value)))
    def add(var a: Int, var b: Int) -> Optional[Int]: return Optional(a + b)
    def text(var value: Int) -> Optional[String]: return Optional(String(value))
    var code = 0
    try: _ = forward_find(choose, List[Int]([1,-2,3]))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, -2)
    assert_equal(forward_map(project, List[Int]([2,3])).value().value(), "2")
    assert_equal(forward_fold(add, 10, List[Int]([2,3])).value(), 15)
    assert_equal(forward_monoid(text, List[Int]([2,3])).value(), "23")
    origins(List[Int]([7,11]), List[Int]([13,17]))
