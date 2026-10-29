from algebra_support.arrows import Produce
from algebra_support.iterators import Counted
from algebra_support.box import Box, BoxMonad
from fp.algebra import StringMonoid
from fp.iteration import iterated
from fp.effects import Reader, State, WriterT, writer, run
from std.memory import ArcPointer
from std.testing import assert_equal

comptime Logged = WriterT[BoxMonad, StringMonoid]

def logged(var value: Int) -> type_of(writer[Logged, Int](Box(Tuple(String(), 0)))):
    return writer[Logged, Int](Box(Tuple(String(value), value)))

def lists(var value: Int) -> Reader[Int].Pure[List[Int]]:
    return Reader[Int].pure(List[Int]([value, value + 10]))

def optional(var value: Int) -> Reader[Int].Pure[Optional[Int]]:
    return Reader[Int].pure(Optional[Int]() if value == 1 else Optional(value))

def main() raises:
    for count in [0,3]:
        var pulls = 0
        var calls = ArcPointer(0)
        var pending = iterated(Counted(Pointer(to=pulls),0,count)).map(Produce[False](calls)).sequence()
        assert_equal(pulls,0)
        assert_equal(calls[],0)
        var environment = 10
        var values = run[Reader[Int]](pending^,environment)
        assert_equal(values,List[Int]() if count == 0 else List[Int]([11,12,13]))
        assert_equal(pulls,count+1)
        assert_equal(calls[],count)
        pulls = 0
        calls[] = 0
        var state = iterated(Counted(Pointer(to=pulls),0,count)).map(Produce[True](calls)).sequence_void()
        assert_equal(pulls,0)
        assert_equal(calls[],0)
        var final_state = run[State[Int]](state^,10)
        assert_equal(final_state[1],10 if count == 0 else 16)
        assert_equal(pulls,count+1)
        assert_equal(calls[],count)
    var abandoned = ArcPointer(0)
    _ = iterated(range(3)).map(Produce[False](abandoned)).sequence()
    _ = iterated(range(3)).map(Produce[True](abandoned)).sequence_void()
    assert_equal(abandoned[],0)
    var environment = 0
    var flat = iterated(range(3)).map(lists).flat_sequence()
    assert_equal(run[Reader[Int]](flat^,environment),[0,10,1,11,2,12])
    var compacted = iterated(range(3)).map(optional).sequence_filter()
    assert_equal(run[Reader[Int]](compacted^,environment),[0,2])
    var written = run[Logged](iterated(range(3)).map(logged).sequence())
    assert_equal(written.value[0],"012")
    assert_equal(written.value[1],[0,1,2])
    var discarded = run[Logged](iterated(range(3)).map(logged).sequence_void())
    assert_equal(discarded.value[0],"012")
