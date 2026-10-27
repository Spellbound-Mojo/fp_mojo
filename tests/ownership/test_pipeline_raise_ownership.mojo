from fp.data import Result, Ok, Err, ok, err
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct RaisedOwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def consume(present: Bool, values: ArcPointer[Int], errors: ArcPointer[Int]) -> String:
    var source: Result[RaisedOwner, RaisedOwner]
    if present: source = Ok(RaisedOwner("success", values))
    else: source = Err(RaisedOwner("failure", errors))
    try:
        var value = pipeline(source^).raise_on_err()
        return value.name.copy()
    except error:
        comptime assert type_of(error) == RaisedOwner
        return error.name.copy()

def exact_origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var failure = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(failure)
    var value = pipeline(ok[Never](view)).raise_on_err()
    comptime assert type_of(value) == View
    assert_equal(Pointer(to=value[0]) == Pointer(to=owner[0]), True)
    var matched = False
    try:
        _ = pipeline(err[Int](failure)).raising[String]().raise_on_err()
    except error:
        comptime assert type_of(error) == Failure
        matched = Pointer(to=error[0]) == Pointer(to=other[0])
    assert_equal(matched, True)

def main() raises:
    for present in range(2):
        var values = ArcPointer(0)
        var errors = ArcPointer(0)
        assert_equal(consume(Bool(present), values, errors), "success" if present else "failure")
        assert_equal(values[], present)
        assert_equal(errors[], 1 - present)
    var owner: List[Int] = [3]
    var other: List[Int] = [7]
    exact_origins(owner, other)
