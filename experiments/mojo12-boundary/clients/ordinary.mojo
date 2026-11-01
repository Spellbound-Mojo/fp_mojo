from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct PilotFault(Movable):
    var code: Int
def select(value: Int) -> Bool: return value > 1
def transform(var value: Int) -> String: return String(value)
def source() -> Int: return 7
def main() raises:
    var output = piped(List[Int]([1, 2, 3])).filter(select).map(transform).get()
    assert_equal(output, List[String](["2", "3"]))
    var optional = piped(Optional(4)).map(transform).get()
    assert_equal(optional.take(), "4")
    var result = piped(Result[Int, String](Ok(5))).map(transform).get()
    assert_equal(result._ok().value, "5")
    assert_equal(attempt(source)._ok().value, 7)
