"""Payload, projected, stored-error and native-error origins remain distinct."""
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.algebra import ResultFamily, ValidationFamily, ListMonoid
from std.testing import assert_equal

def check(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def project(value: Int) {view} -> View: return view
    def inspect(value: View) -> Int: return value[0]
    def reject(value: View) -> Bool: return False
    var kept = pipeline(Optional(view)).tap_each(inspect).filter_not(reject).get()
    assert_equal(Pointer(to=kept.value()[0]) == Pointer(to=owner[0]), True)
    var pairs = pipeline(List[Int]([1, 2])).pair_with(project).get()
    assert_equal(Pointer(to=pairs[1][1][0]) == Pointer(to=owner[0]), True)
    def retain(value: View) -> View: return value
    var pointer: def(View) thin -> View = retain
    var borrowed_pair = pipeline(Optional(view)).pair_with(pointer).get()
    assert_equal(Pointer(to=borrowed_pair.value()[1][1]) == Pointer(to=owner[1]), True)
    assert_equal(pipeline(3).tap(project).get(), 3)
    comptime Stored = List[View]
    var stored = pipeline[ResultFamily[Stored]](Result[Int, Stored](Err(Stored([view])))).tap_each(project).pair_with(project).get()
    assert_equal(Pointer(to=stored._err().value[0][1]) == Pointer(to=owner[1]), True)
    var validated = pipeline[ValidationFamily[ListMonoid[View]]](Result[Int, Stored](Ok(5))).pair_with(project).get()
    assert_equal(Pointer(to=validated._ok().value[1][1]) == Pointer(to=owner[1]), True)
    def fail(value: Int) raises View {view} -> Int: raise view
    var same_origin = False
    try: _ = pipeline(1).raising[View]().tap(fail).get()
    except error: same_origin = Pointer(to=error[0]) == Pointer(to=owner[0])
    assert_equal(same_origin, True)
    same_origin = False
    try: _ = pipeline(Result[Int, Stored](Ok(1))).raising[View]().pair_with(fail).get()
    except error: same_origin = Pointer(to=error[1]) == Pointer(to=owner[1])
    assert_equal(same_origin, True)

def main() raises:
    var owner = List[Int]([7, 11])
    check(owner)

