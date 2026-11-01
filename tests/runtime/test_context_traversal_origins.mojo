"""Retained payloads, source errors, target errors and raised errors retain owners."""
from fp.functions import pipeline
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Ok, Err
from std.testing import assert_equal

def check(owner: List[Int], failure_owner: List[Int]) raises:
    var view = Span(owner)
    var failure = Span(failure_owner)
    comptime View = type_of(view)
    comptime Failure = type_of(failure)
    def accept(value: View) -> Optional[Bool]: return Optional(True)
    var retained = pipeline(List[View]([view])).filter_effect(accept).get()
    assert_equal(Pointer(to=retained.value()[0][0]) == Pointer(to=owner[0]), True)
    def inspect(value: View) {failure} -> Result[Failure, Failure]: return Ok(failure)
    var tapped = pipeline(List[View]([view])).traverse_tap(inspect).get()
    assert_equal(Pointer(to=tapped._ok().value[0][1]) == Pointer(to=owner[1]), True)
    var stored_source = pipeline(Result[View, Failure](Err(failure))).traverse_tap(accept).get()
    assert_equal(Pointer(to=stored_source.value()._err().value[0]) == Pointer(to=failure_owner[0]), True)
    def reject(value: View) {failure} -> Result[Bool, Failure]: return Err(failure)
    var stored_target = pipeline(List[View]([view])).filter_effect(reject).get()
    assert_equal(Pointer(to=stored_target._err().value[1]) == Pointer(to=failure_owner[1]), True)
    comptime Stored = List[Failure]
    def validate(value: View) {failure} -> Result[Bool, Stored]: return Err(Stored([failure]))
    var validated = pipeline(List[View]([view, view])).filter_effect[ValidationFamily[ListMonoid[Failure]]](validate).get()
    assert_equal(len(validated._err().value), 2)
    assert_equal(Pointer(to=validated._err().value[1][0]) == Pointer(to=failure_owner[0]), True)
    def raise_view(value: View) raises Failure {failure} -> Optional[Bool]: raise failure
    var matched = False
    try: _ = pipeline(List[View]([view])).raising[Failure]().filter_effect(raise_view).get()
    except error: matched = Pointer(to=error[0]) == Pointer(to=failure_owner[0])
    assert_equal(matched, True)
    matched = False
    try: _ = pipeline(List[View]([view])).raising[Failure]().traverse_tap(raise_view).get()
    except error: matched = Pointer(to=error[1]) == Pointer(to=failure_owner[1])
    assert_equal(matched, True)

def main() raises:
    var owner = List[Int]([7, 11])
    var failure = List[Int]([13, 17])
    check(owner, failure)

