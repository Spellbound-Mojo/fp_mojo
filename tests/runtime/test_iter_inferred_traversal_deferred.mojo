from algebra_support.arrows import Produce
from algebra_support.iterators import Counted
from algebra_support.box import Box, BoxMonad
from fp.algebra import StringMonoid
from fp.iteration import iterated
from fp.effects import Reader, State, WriterT, writer, run
from std.memory import ArcPointer
from std.testing import assert_equal


comptime Logged = WriterT[BoxMonad, StringMonoid]

def boxed(var value: Int) -> Box[Int]: return Box(value)

def logged(var value: Int) -> type_of(writer[Logged, Int](Box(Tuple(String(), 0)))):
    return writer[Logged, Int](Box(Tuple(String(value), value)))


def main() raises:
    for count in [0, 3]:
        var pulls = 0
        var calls = ArcPointer(0)
        var reader = iterated(Counted(Pointer(to=pulls), 0, count)).traverse(Produce[False](calls))
        assert_equal(pulls, 0)
        assert_equal(calls[], 0)
        var environment = 10
        var values = run[Reader[Int]](reader^, environment)
        assert_equal(values, List[Int]() if count == 0 else List[Int]([11, 12, 13]))
        assert_equal(pulls, count + 1)
        assert_equal(calls[], count)

        pulls = 0
        calls[] = 0
        var state = iterated(Counted(Pointer(to=pulls), 0, count)).traverse(Produce[True](calls))
        assert_equal(pulls, 0)
        assert_equal(calls[], 0)
        var output = run[State[Int]](state^, 10)
        assert_equal(output[0], List[Int]() if count == 0 else List[Int]([11, 13, 16]))
        assert_equal(output[1], 10 if count == 0 else 16)
        assert_equal(calls[], count)

        calls[] = 0
        var reader_void = iterated(range(count)).traverse_void(Produce[False](calls))
        assert_equal(calls[], 0)
        _ = run[Reader[Int]](reader_void^, environment)
        assert_equal(calls[], count)
        calls[] = 0
        var state_void = iterated(range(count)).traverse_void(Produce[True](calls))
        assert_equal(calls[], 0)
        var final_state = run[State[Int]](state_void^, 10)
        assert_equal(final_state[1], 10 if count == 0 else 13)
        assert_equal(calls[], count)

    var abandoned = ArcPointer(0)
    _ = iterated(range(3)).traverse(Produce[False](abandoned))
    _ = iterated(range(3)).traverse_void(Produce[True](abandoned))
    assert_equal(abandoned[], 0)
    # An external target stays selectable; declared Writer recipes infer it.
    var custom = iterated(range(3)).traverse[BoxMonad](boxed)
    assert_equal(custom.value, [0, 1, 2])
    _ = iterated(range(3)).traverse_void[BoxMonad](boxed)
    var written = run[Logged](iterated(range(3)).traverse(logged))
    assert_equal(written.value[0], "012")
    assert_equal(written.value[1], [0, 1, 2])
    var discarded = run[Logged](iterated(range(3)).traverse_void(logged))
    assert_equal(discarded.value[0], "012")
