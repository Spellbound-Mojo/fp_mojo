"""Only the selected mapping arm runs; both owned callbacks are disposed once."""
from fp.callables import OnceUnary
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal
from test_shared_outcomes_ownership import SOOwner

@fieldwise_init
struct Mapping(OnceUnary):
    var output: SOOwner
    var calls: ArcPointer[Int]
    var amount: Int
    var throws: Bool
    comptime Arg = SOOwner
    comptime Out = SOOwner
    comptime Error = Int
    def call_once(deinit self, var value: SOOwner) raises Int -> SOOwner:
        self.calls[] += self.amount
        if self.throws: raise 761 + self.amount
        return self.output^

def both(drops: ArcPointer[Int], calls: ArcPointer[Int], failed: Bool, throws: Bool) -> Int:
    comptime R = Result[SOOwner, SOOwner]
    var source = R(Err(SOOwner(1, drops))) if failed else R(Ok(SOOwner(1, drops)))
    try:
        var mapped = pipeline(source^).map_both(Mapping(SOOwner(2, drops), calls, 1, throws), Mapping(SOOwner(3, drops), calls, 10, throws)).get()
        if mapped.is_ok(): return mapped._ok().value.value
        return mapped._err().value.value
    except error:
        comptime assert type_of(error) == Int
        return error

def error_only(drops: ArcPointer[Int], calls: ArcPointer[Int], failed: Bool, throws: Bool) -> Int:
    comptime R = Result[SOOwner, SOOwner]
    var source = R(Err(SOOwner(1, drops))) if failed else R(Ok(SOOwner(1, drops)))
    try:
        var mapped = pipeline(source^).map_err(Mapping(SOOwner(2, drops), calls, 1, throws)).get()
        if mapped.is_ok(): return mapped._ok().value.value
        return mapped._err().value.value
    except error:
        comptime assert type_of(error) == Int
        return error

def main() raises:
    for failed in range(2):
        for throws in range(2):
            var drops = ArcPointer(0)
            var calls = ArcPointer(0)
            assert_equal(both(drops, calls, Bool(failed), Bool(throws)), (771 if failed else 762) if throws else (3 if failed else 2))
            assert_equal(calls[], 10 if failed else 1)
            assert_equal(drops[], 3)
            var err_drops = ArcPointer(0)
            var err_calls = ArcPointer(0)
            assert_equal(error_only(err_drops, err_calls, Bool(failed), Bool(throws)), (762 if throws else 2) if failed else 1)
            assert_equal(err_calls[], 1 if failed else 0)
            assert_equal(err_drops[], 2)
