"""IO keeps plain functions, including consuming ones, and live closures, with inferred families."""
from fp.algebra import pure, map, flat_map, traverse
from fp.functions import piped
from fp.effects import IO, run_io
from std.testing import assert_equal
def inc(var value: Int) -> Int: return value + 1
def lift(var value: Int) -> IO[Int].Pure[Int]: return pure[IO[Int]](value * 2)
def check(var value: Int) -> IO[Int].Pure[Int]: return pure[IO[Int]](value + 1)
def main() raises:
    var a = run_io(map(pure[IO[Int]](20), inc))
    assert_equal(a.value()._ok().value, 21)
    var b = run_io(flat_map(pure[IO[Int]](20), lift))
    assert_equal(b.value()._ok().value, 40)
    var c = run_io(piped(pure[IO[Int]](20)).map(inc).get())
    assert_equal(c.value()._ok().value, 21)
    var d = run_io(traverse(List[Int]([1, 2]), check))
    assert_equal(d.value()._ok().value, [2, 3])
    var k = 5
    def add(var value: Int) {k} -> Int: return value + k
    var e = run_io(map(pure[IO[Int]](1), add))
    assert_equal(e.value()._ok().value, 6)

