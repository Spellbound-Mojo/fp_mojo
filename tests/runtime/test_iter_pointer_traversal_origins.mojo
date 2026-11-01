from fp.iteration import iterated
from fp.data import Result, Err
from std.testing import assert_equal


def check(owner: List[Int], other: List[Int]) raises:
    comptime View = type_of(Span(owner))
    comptime Failure = type_of(Span(other))
    def keep(var value: View) -> Optional[View]: return Optional(value)
    def fail(var error: Failure) -> Result[View, Failure]: return Err(error)
    var keep_pointer: def(var View) thin -> Optional[View] = keep
    var fail_pointer: def(var Failure) thin -> Result[View, Failure] = fail
    var output = iterated(List[View]([Span(owner)])).traverse(keep_pointer)
    comptime assert type_of(output) == Optional[List[View]]
    assert_equal(Pointer(to=output.value()[0][0]) == Pointer(to=owner[0]), True)
    var failed = iterated(List[Failure]([Span(other)])).traverse(fail_pointer)
    comptime assert type_of(failed) == Result[List[View], Failure]
    var error = failed^.swap().to_optional()
    assert_equal(Pointer(to=error.value()[0]) == Pointer(to=other[0]), True)
    var discarded = iterated(List[Failure]([Span(other)])).traverse_void(fail_pointer)
    comptime assert type_of(discarded) == Result[NoneType, Failure]
    var void_error = discarded^.swap().to_optional()
    assert_equal(Pointer(to=void_error.value()[0]) == Pointer(to=other[0]), True)


def main() raises:
    check([3], [7])
