from fp.functions import pipeline
from fp.data import Result
from fp.callables import OnceThunk
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct OROwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
@fieldwise_init
struct ORFault(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
@fieldwise_init
struct ORFactory(OnceThunk):
    var output: OROwner
    var calls: ArcPointer[Int]
    var errors: ArcPointer[Int]
    var throwing: Bool
    comptime Out = OROwner
    comptime Error = ORFault
    def call_once(deinit self) raises ORFault -> OROwner:
        self.calls[] += 1
        if self.throwing: raise ORFault(self.errors)
        return self.output^

def or_origins(owner: List[Int], stored: List[Int], native: List[Int]) raises:
    var value = Span(owner)
    var error = Span(stored)
    var failure = Span(native)
    comptime T = type_of(value)
    comptime E = type_of(error)
    comptime X = type_of(failure)
    def make_error() {error} -> E: return error
    for present in range(2):
        var source = Optional(value) if present else Optional[T]()
        var result = pipeline(source^).to_result(make_error).get()
        comptime assert type_of(result) == Result[T,E]
        if present: assert_equal(Pointer(to=result._ok().value[0]) == Pointer(to=owner[0]), True)
        else: assert_equal(Pointer(to=result._err().value[0]) == Pointer(to=stored[0]), True)
    def failed() raises X {failure} -> E: raise failure
    var caught = False
    try: _ = pipeline(Optional[T]()).raising[X]().to_result(failed)
    except got:
        comptime assert type_of(got) == X
        caught = Pointer(to=got[0]) == Pointer(to=native[0])
    assert_equal(caught, True)

def main() raises:
    for present in range(2):
        for throwing in range(2):
            var inputs = ArcPointer(0)
            var errors = ArcPointer(0)
            var native_errors = ArcPointer(0)
            var calls = ArcPointer(0)
            var source = Optional(OROwner("value", inputs)) if present else Optional[OROwner]()
            var factory = ORFactory(OROwner("error", errors), calls, native_errors, Bool(throwing))
            var caught = False
            var name = String()
            var succeeded = False
            try:
                var result = pipeline(source^).to_result(factory^).get()
                succeeded = result.is_ok()
                if result.is_ok(): name = result._ok().value.name.copy()
                else: name = result._err().value.name.copy()
            except error:
                comptime assert type_of(error) == ORFault
                caught = True
            assert_equal(caught, Bool(not present and throwing))
            assert_equal(succeeded, Bool(present))
            assert_equal(name, "value" if present else "" if throwing else "error")
            assert_equal(inputs[], present)
            assert_equal(errors[], 1)
            assert_equal(calls[], 0 if present else 1)
            assert_equal(native_errors[], 1 if caught else 0)
    var captures = ArcPointer(0)
    var owner = OROwner("missing", captures)
    def native() {var owner^} -> String: return owner.name.copy()
    assert_equal(pipeline(Optional(3)).to_result(native).get()._ok().value, 3)
    assert_equal(pipeline(Optional[Int]()).to_result(native).get()._err().value, "missing")
    assert_equal(captures[], 0)
    assert_equal(native(), "missing")
    _ = native^
    assert_equal(captures[], 1)
    var a: List[Int] = [1]
    var b: List[Int] = [2]
    var c: List[Int] = [3]
    or_origins(a, b, c)
