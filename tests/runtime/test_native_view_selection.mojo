"""Borrowed native predicates choose the same branches at O0 and O3."""
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.data import Result, Ok, Err
from fp.functions import piped
from std.testing import assert_equal

comptime Entry = Result[Int, String]
comptime Entries = ResultT[ListFamily, String]

def positive(value: Int) -> Bool:
    return value > 0

def rejection(value: Int) -> String:
    return "nonpositive"

def main() raises:
    var values: List[Entry] = [Entry(Ok(3)), Entry(Ok(-2)), Entry(Err(String("old")))]
    var results = piped(values^).ensure[Entries](positive, rejection).get()
    assert_equal(results[0]._ok().value, 3)
    assert_equal(results[1]._err().value, "nonpositive")
    assert_equal(results[2]._err().value, "old")

    var checks = 0
    var rejected = 0
    def predicate(value: Int) {mut checks} -> Bool:
        checks += 1
        return value > 0
    def factory(value: Int) {mut rejected} -> String:
        rejected += 1
        return String(value)
    var captured: List[Entry] = [Entry(Ok(-4)), Entry(Ok(5)), Entry(Err(String("skip")))]
    var kept = piped(captured^).ensure[Entries](predicate, factory).get()
    assert_equal(checks, 2)
    assert_equal(rejected, 1)
    assert_equal(kept[0]._err().value, "-4")
    assert_equal(kept[1]._ok().value, 5)
    assert_equal(kept[2]._err().value, "skip")
