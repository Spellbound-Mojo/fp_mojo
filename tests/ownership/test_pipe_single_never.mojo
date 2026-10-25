"""One-stage explicit Never calls retain owned inputs, reusable captures and void."""
from fp.functions import pipe
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct SingleNeverToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def forward[A: Movable, R: Movable, //, F: def(var A) raises Never -> R](
    var value: A, function: F
) -> R:
    return pipe(value^, function)

def single_never_increment(var value: Int) raises Never -> Int:
    return value + 1

def exercise(drops: ArcPointer[Int]) raises:
    var anchor = SingleNeverToken(10, drops)
    var calls = 0
    def callback(var value: SingleNeverToken) raises Never {var anchor^, mut calls} -> SingleNeverToken:
        calls += 1
        value.value += anchor.value
        return value^
    for i in range(2):
        var input = SingleNeverToken(i, drops)
        var output = forward(input^, callback)
        assert_equal(output.value, 10 + i)
    assert_equal(calls, 2)
    assert_equal(drops[], 2)
    # Keep the captured owner live across the destruction-count observation.
    var last = pipe(SingleNeverToken(5, drops), callback)
    assert_equal(last.value, 15)
    def observe(var value: String) raises Never {mut calls}:
        calls += value.byte_length()
    var nothing = pipe(String("done"), observe)
    comptime assert type_of(nothing) == type_of(None)
    _ = nothing
    assert_equal(calls, 7)

def main() raises:
    assert_equal(pipe(2, single_never_increment), 3)
    assert_equal(forward(4, single_never_increment), 5)
    var drops = ArcPointer(0)
    exercise(drops)
    assert_equal(drops[], 4)
