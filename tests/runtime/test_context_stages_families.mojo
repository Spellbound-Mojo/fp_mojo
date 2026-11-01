"""Combinations keep deferred custom families and accumulating validation."""
from fp.functions import pipeline
from fp.algebra import OptionalFamily, ValidationFamily, ListMonoid
from fp.effects import ReaderT, run
from fp.data import Result, Err
from std.testing import assert_equal

def main() raises:
    comptime Reader = ReaderT[OptionalFamily, Int]
    var calls = 0
    def add(var a: Int, var b: Int) {mut calls} -> Int:
        calls += 1
        return a + b
    var pending = pipeline[Reader](Reader.pure(2)).map2(Reader.pure(3), add).get()
    assert_equal(calls, 0)
    var output = run[Reader](pending^, 0)
    assert_equal(output.value(), 5)
    assert_equal(calls, 1)
    var more = pipeline[Reader](Reader.pure(4)).map_n((Reader.pure(5),), add).get()
    assert_equal(calls, 1)
    var done = run[Reader](more^, 0)
    assert_equal(done.value(), 9)
    assert_equal(calls, 2)

    comptime Validation = ValidationFamily[ListMonoid[String]]
    var failed = pipeline[Validation](Result[Int, List[String]](Err(List[String](["first"])))).map_n((Result[Int, List[String]](Err(List[String](["second"]))),), add).get()
    assert_equal(failed._err().value, List[String](["first", "second"]))
    assert_equal(calls, 2)
