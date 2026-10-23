"""Validate and observe each selected outcome through one fluent family chain."""
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.data import Result, Ok, Err
from fp.functions import piped
from std.testing import assert_equal

comptime Entry = Result[Int, String]
comptime Entries = ResultT[ListFamily, String]

def positive_entry(value: Int) -> Bool: return value > 0
def reject_entry(value: Int) -> String: return "nonpositive"

def inspect_entry(outcome: Entry) -> List[Result[NoneType, String]]:
    print("observed failure:", outcome.is_err())
    return [Result[NoneType, String](Ok(NoneType()))]

def double_entry(var value: Int) -> List[Entry]: return [Entry(Ok(value * 2))]

def recover_entry(var error: String) -> List[Entry]:
    if error == "missing": return [Entry(Ok(0))]
    return [Entry(Err(error^))]

def render_entry(var value: Int) -> String: return "value=" + String(value)
def explain_entry(var error: String) -> String: return "failed: " + error

def main() raises:
    var source: List[Entry] = [Entry(Ok(4)), Entry(Ok(-1)), Entry(Err(String("missing")))]
    var results = (
        piped(source^)
        .ensure[Entries](positive_entry, reject_entry)
        .attempt_tap[Entries](inspect_entry)
        .redeem_with[Entries](double_entry, recover_entry)
        .redeem[Entries](render_entry, explain_entry)
        .get()
    )
    assert_equal(len(results), 3)
    assert_equal(results[0]._ok().value, "value=8")
    assert_equal(results[1]._ok().value, "failed: nonpositive")
    assert_equal(results[2]._ok().value, "value=0")
    for result in results:
        print(result._ok().value)
