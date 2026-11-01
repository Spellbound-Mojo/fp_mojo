"""Terminal operations preserve move-only owners, borrowed captures and origins."""
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from fp.callables import OnceUnary, OnceThunk
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true, assert_false


@fieldwise_init
struct RTOwner(Movable):
    var name: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def rto_name(var value: RTOwner) -> String: return value.name.copy()
def rto_identity(var value: RTOwner) -> RTOwner: return value^
def rto_raise(var value: RTOwner) raises RTOwner -> RTOwner: raise value^


@fieldwise_init
struct RTOFallback(OnceThunk):
    var output: RTOwner
    var calls: ArcPointer[Int]
    var throwing: Bool
    comptime Out = RTOwner
    comptime Error = RTOwner
    def call_once(deinit self) raises RTOwner -> RTOwner:
        self.calls[] += 1
        if self.throwing: raise self.output^
        return self.output^


@fieldwise_init
struct RTOHandler(OnceUnary):
    var fallback: RTOFallback
    comptime Arg = RTOwner
    comptime Out = RTOwner
    comptime Error = RTOwner
    def call_once(deinit self, var error: RTOwner) raises RTOwner -> RTOwner:
        return self.fallback^.call_once()


def rto_fallbacks() raises:
    for factory in range(2):
        for failed in range(2):
            for throwing in range(2):
                var inputs = ArcPointer(0)
                var defaults = ArcPointer(0)
                var calls = ArcPointer(0)
                var input = RTOwner("original", inputs)
                var source = Result[RTOwner, RTOwner](Err(input^)) if failed else Result[RTOwner, RTOwner](Ok(input^))
                var fallback = RTOFallback(RTOwner("fallback", defaults), calls, Bool(throwing))
                var name: String
                var caught = False
                try:
                    var output: RTOwner
                    if factory: output = source^.get_or_else(fallback^)
                    else: output = source^.value_or(RTOHandler(fallback^))
                    name = rto_name(output^)
                except error:
                    comptime assert type_of(error) == RTOwner
                    name = rto_name(error^)
                    caught = True
                assert_equal(name, "fallback" if failed else "original")
                assert_equal(caught, Bool(failed and throwing))
                assert_equal(calls[], failed)
                assert_equal(inputs[], 1)
                assert_equal(defaults[], 1)


def rto_native_and_optional() raises:
    var raised_drops = ArcPointer(0)
    var caught_name = String()
    try:
        var failed = Result[RTOwner, RTOwner](Err(RTOwner("raised owner", raised_drops)))
        _ = failed^.value_or(rto_raise)
    except error:
        comptime assert type_of(error) == RTOwner
        caught_name = rto_name(error^)
    assert_equal(caught_name, "raised owner")
    assert_equal(raised_drops[], 1)
    for failed in range(2):
        var drops = ArcPointer(0)
        var input = RTOwner("input", drops)
        var source = Result[RTOwner, RTOwner](Err(input^)) if failed else Result[RTOwner, RTOwner](Ok(input^))
        var output = source^.value_or(rto_identity)
        assert_equal(drops[], 0)
        assert_equal(rto_name(output^), "input")
        assert_equal(drops[], 1)

        var optional_input = RTOwner("optional", drops)
        var optional_source = Result[RTOwner, RTOwner](Err(optional_input^)) if failed else Result[RTOwner, RTOwner](Ok(optional_input^))
        var optional = optional_source^.to_optional()
        comptime assert type_of(optional) == Optional[RTOwner]
        assert_equal(Bool(optional), not Bool(failed))
        if failed:
            assert_equal(drops[], 2)
        else:
            assert_equal(drops[], 1)
            assert_equal(rto_name(optional.take()), "optional")
            assert_equal(drops[], 2)

    var captures = ArcPointer(0)
    var capture = RTOwner("captured", captures)
    def native(var error: Int) {var capture^} -> Int:
        return error + capture.name.byte_length()
    var failed = Result[Int, Int](Err(3))
    assert_equal(failed^.value_or(native), 11)
    assert_equal(captures[], 0)
    assert_equal(native(4), 12)
    _ = native^
    assert_equal(captures[], 1)
    var default_capture = RTOwner("default", captures)
    def default() {var default_capture^} -> Int:
        return default_capture.name.byte_length()
    var success = Result[Int, Int](Ok(5))
    assert_equal(success^.get_or_else(default), 5)
    assert_equal(captures[], 1)
    var default_failure = Result[Int, Int](Err(0))
    assert_equal(default_failure^.get_or_else(default), 7)
    assert_equal(captures[], 1)
    _ = default^
    assert_equal(captures[], 2)


def rto_origins(first: List[Int], second: List[Int], third: List[Int]) raises:
    var a = Span(first)
    var b = Span(second)
    var c = Span(third)
    comptime A = type_of(a)
    comptime B = type_of(b)
    comptime C = type_of(c)
    def fallback(var error: B) {a} -> A: return a
    def default() {a} -> A: return a
    def failure(var error: B) raises C {c} -> A: raise c
    def default_failure() raises C {c} -> A: raise c
    for failed in range(2):
        var source = Result[A, B](Err(b)) if failed else Result[A, B](Ok(a))
        var result = source^.value_or(fallback)
        comptime assert type_of(result) == A
        assert_true(Pointer(to=result[0]) == Pointer(to=first[0]))
        var default_source = Result[A, B](Err(b)) if failed else Result[A, B](Ok(a))
        var default_result = default_source^.get_or_else(default)
        comptime assert type_of(default_result) == A
        assert_true(Pointer(to=default_result[0]) == Pointer(to=first[0]))
        var optional_source = Result[A, B](Err(b)) if failed else Result[A, B](Ok(a))
        var optional = optional_source^.to_optional()
        comptime assert type_of(optional) == Optional[A]
        if failed: assert_false(optional)
        else: assert_true(Pointer(to=optional.value()[0]) == Pointer(to=first[0]))
        for factory in range(2):
            var throwing_source = Result[A, B](Err(b)) if failed else Result[A, B](Ok(a))
            var caught = False
            try:
                if factory: _ = pipeline(throwing_source^).raising[C]().get_or_else(default_failure)
                else: _ = pipeline(throwing_source^).raising[C]().value_or(failure)
            except error:
                comptime assert type_of(error) == C
                assert_true(Pointer(to=error[0]) == Pointer(to=third[0]))
                caught = True
            assert_equal(caught, Bool(failed))


def main() raises:
    rto_fallbacks()
    rto_native_and_optional()
    var a: List[Int] = [7]
    var b: List[Int] = [9]
    var c: List[Int] = [11]
    rto_origins(a, b, c)
