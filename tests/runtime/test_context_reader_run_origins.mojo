from context_reader_run_support import Produce, Once, Length, Continue
from fp.effects import Reader, run
from fp.algebra import OptionalFamily, traverse
from std.testing import assert_equal

def check[a: ImmOrigin](ref[a] first: Int) raises:
    comptime I = Reader[Int]
    comptime F = Produce[a]
    comptime Collected = I.Collected[List[Int], F]
    comptime assert I.CollectCompatible[List[Int], F]
    comptime assert not I.CollectCompatible[List[Int], Once]
    comptime assert I.RunCompatible[Collected, a]
    comptime assert I.RunCompatible[I.Mapped[Collected, Length], a]
    comptime assert I.RunCompatible[I.Bound[Collected, Continue], a]
    # The single-value Optional source consumes its producer once and never
    # uses the collection hook, so its existing consuming API stays available.
    var single = traverse[I, OptionalFamily](Optional(7), Once())
    assert_equal(run[I](single^, first).value(), 7)
    for value in [-1, 1]:
        var caught = False
        try:
            _ = run[I](I.collect(F(Pointer(to=first)), List[Int]([value])), first)
        except error:
            comptime assert type_of(error) == Pointer[Int, a]
            caught = error == Pointer(to=first)
        assert_equal(caught, True)

def incompatible[a: ImmOrigin, b: ImmOrigin](ref[a] first: Int, ref[b] second: Int) where (
    not Reader[Int].RunCompatible[Reader[Int].Collected[List[Int], Produce[a]], b] and
    not Reader[Int].RunCompatible[Reader[Int].Mapped[Reader[Int].Collected[List[Int], Produce[a]], Length], b] and
    not Reader[Int].RunCompatible[Reader[Int].Bound[Reader[Int].Collected[List[Int], Produce[a]], Continue], b]
):
    pass

def main() raises:
    var first = 1
    var second = 2
    incompatible(first, second)
    check(first)
