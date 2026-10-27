from fp.algebra import Applicative, OptionalFamily, StringMonoid, pure
from fp.effects import WriterT, ReaderT, run, run_writer
from std.testing import assert_equal


def initialize[I: Applicative, A: Movable & Deinitable](var value: A) -> I.Pure[A]:
    return pure[I](value^)


def main() raises:
    comptime W = WriterT[OptionalFamily, StringMonoid]
    var direct = run_writer[W](initialize[W](7))
    assert_equal(direct.value()[0], "")
    assert_equal(direct.value()[1], 7)
    comptime R = ReaderT[W, Int]
    var deferred = initialize[R](11)
    var output = run_writer[W](run[R](deferred^, 0))
    assert_equal(output.value()[1], 11)
    print("pure construction: direct=", direct.value()[1], "; deferred=", output.value()[1], sep="")
