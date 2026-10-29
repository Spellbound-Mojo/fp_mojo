"""Borrowed chains preserve unique payload ownership and independent origins."""
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Err
from test_iter_inferred_post_traversal_owned import Token, Select, Expand, values
from std.memory import ArcPointer
from std.testing import assert_equal

def origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var error = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(error)
    def keep(var value: View) -> Optional[Optional[View]]: return Optional(Optional(value))
    def expand(var value: View) -> Optional[List[View]]: return Optional(List[View]([value]))
    var selector = kleisli[OptionalFamily](keep)
    var expander = kleisli[OptionalFamily](expand)
    var selected = iterated(List[View]([view])).traverse_filter(selector)
    var flattened = iterated(List[View]([view])).flat_traverse(expander)
    assert_equal(Pointer(to=selected.value()[0][0]) == Pointer(to=owner[0]),True)
    assert_equal(Pointer(to=flattened.value()[0][0]) == Pointer(to=owner[0]),True)
    def fail(var value: View) {error} -> Result[Optional[View],Failure]: return Err(error)
    def fail_flat(var value: View) {error} -> Result[List[View],Failure]: return Err(error)
    var failing = kleisli[ResultFamily[Failure]](fail)
    var failing_flat = kleisli[ResultFamily[Failure]](fail_flat)
    var failure = iterated(List[View]([view])).traverse_filter(failing)
    var flat_failure = iterated(List[View]([view])).flat_traverse(failing_flat)
    var stored = failure^.swap().to_optional()
    var flat_stored = flat_failure^.swap().to_optional()
    assert_equal(Pointer(to=stored.value()[0]) == Pointer(to=other[0]),True)
    assert_equal(Pointer(to=flat_stored.value()[0]) == Pointer(to=other[0]),True)

def main() raises:
    var drops = ArcPointer(0)
    var selector = kleisli[OptionalFamily](Select())
    var expander = kleisli[OptionalFamily](Expand())
    var selected = iterated(values(drops)).traverse_filter(selector)
    assert_equal(drops[],1)
    assert_equal(len(selected.value()),2)
    _ = selected^
    assert_equal(drops[],3)
    var flattened = iterated(values(drops)).flat_traverse(expander)
    assert_equal(drops[],3)
    assert_equal(len(flattened.value()),3)
    _ = flattened^
    assert_equal(drops[],6)
    _ = selector.call(Token(2,drops))
    _ = expander.call(Token(2,drops))
    assert_equal(drops[],8)
    origins([3],[7])
