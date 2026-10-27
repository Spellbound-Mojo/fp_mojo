from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct DefaultOwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def extract_result(present: Bool, selected: Bool, inputs: ArcPointer[Int], errors: ArcPointer[Int], defaults: ArcPointer[Int]) -> String:
    var source: Result[DefaultOwner, DefaultOwner]
    if present: source = Ok(DefaultOwner("original", inputs))
    else: source = Err(DefaultOwner("error", errors))
    var fallback = DefaultOwner("default", defaults)
    var value: DefaultOwner
    if selected: value = pipeline(source^).get_or(fallback^)
    else: value = source^.get_or(fallback^)
    return value.name.copy()

def extract_optional(present: Bool, inputs: ArcPointer[Int], defaults: ArcPointer[Int]) -> String:
    var source = Optional(DefaultOwner("original", inputs)) if present else Optional[DefaultOwner]()
    var value = pipeline(source^).get_or(DefaultOwner("default", defaults))
    return value.name.copy()

def exact_origins(owner: List[Int]) raises:
    var first = Span(owner)
    var second = Span(owner)
    comptime View = type_of(first)
    for present in range(2):
        var optional = Optional(first) if present else Optional[View]()
        var a = pipeline(optional^).get_or(second)
        var source: Result[View, Int] = Ok(first) if present else Err(3)
        var other = source.copy()
        var b = source^.get_or(second)
        var c = pipeline(other^).get_or(second)
        comptime assert type_of(a) == View and type_of(b) == View and type_of(c) == View
        assert_equal(Pointer(to=a[0]) == Pointer(to=owner[0]), True)
        assert_equal(Pointer(to=b[0]) == Pointer(to=owner[0]), True)
        assert_equal(Pointer(to=c[0]) == Pointer(to=owner[0]), True)

def main() raises:
    for present in range(2):
        for selected in range(2):
            var inputs = ArcPointer(0)
            var errors = ArcPointer(0)
            var defaults = ArcPointer(0)
            assert_equal(extract_result(Bool(present), Bool(selected), inputs, errors, defaults), "original" if present else "default")
            assert_equal(inputs[], present)
            assert_equal(errors[], 1 - present)
            assert_equal(defaults[], 1)
        var inputs = ArcPointer(0)
        var defaults = ArcPointer(0)
        assert_equal(extract_optional(Bool(present), inputs, defaults), "original" if present else "default")
        assert_equal(inputs[], present)
        assert_equal(defaults[], 1)
    var owner: List[Int] = [3]
    exact_origins(owner)
