from fp.functions import pipeline
from fp.callables import OnceThunk
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct ODOwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct ODFallback(OnceThunk):
    var output: ODOwner
    var calls: ArcPointer[Int]
    var throwing: Bool
    comptime Out = ODOwner
    comptime Error = ODOwner
    def call_once(deinit self) raises ODOwner -> ODOwner:
        self.calls[] += 1
        if self.throwing: raise self.output^
        return self.output^

def od_origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var error = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(error)
    def default() {view} -> View: return view
    for present in range(2):
        var source = Optional(view) if present else Optional[View]()
        var result = pipeline(source^).get_or_else(default)
        comptime assert type_of(result) == View
        assert_equal(Pointer(to=result[0]) == Pointer(to=owner[0]), True)
    def failed() raises Failure {error} -> View: raise error
    var caught = False
    try: _ = pipeline(Optional[View]()).raising[Failure]().get_or_else(failed)
    except value:
        comptime assert type_of(value) == Failure
        caught = Pointer(to=value[0]) == Pointer(to=other[0])
    assert_equal(caught, True)

def main() raises:
    for present in range(2):
        for throwing in range(2):
            var inputs = ArcPointer(0)
            var defaults = ArcPointer(0)
            var calls = ArcPointer(0)
            var source = Optional(ODOwner("original", inputs)) if present else Optional[ODOwner]()
            var fallback = ODFallback(ODOwner("default", defaults), calls, Bool(throwing))
            var name: String
            var caught = False
            try:
                var result = pipeline(source^).get_or_else(fallback^)
                name = result.name.copy()
            except error:
                comptime assert type_of(error) == ODOwner
                name = error.name.copy()
                caught = True
            assert_equal(name, "original" if present else "default")
            assert_equal(caught, Bool(not present and throwing))
            assert_equal(inputs[], present)
            assert_equal(defaults[], 1)
            assert_equal(calls[], 0 if present else 1)

    var captures = ArcPointer(0)
    var owned = ODOwner("captured", captures)
    def closure() {var owned^} -> Int: return owned.name.byte_length()
    assert_equal(pipeline(Optional(2)).get_or_else(closure), 2)
    assert_equal(pipeline(Optional[Int]()).get_or_else(closure), 8)
    assert_equal(captures[], 0)
    assert_equal(closure(), 8)
    _ = closure^
    assert_equal(captures[], 1)
    var owner: List[Int] = [3]
    var other: List[Int] = [7]
    od_origins(owner, other)
