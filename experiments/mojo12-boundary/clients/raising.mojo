from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct PilotFault(Movable):
    var code: Int
def select(value: Int) raises PilotFault -> Bool: return value > 1
def transform(var value: Int) raises PilotFault -> Int:
    if value == 3: raise PilotFault(33)
    return value * 2
def source() raises PilotFault -> Int: raise PilotFault(17)
def main() raises:
    var code = 0
    try: _ = piped(List[Int]([1, 2, 3])).raising[PilotFault]().filter(select).map(transform).get()
    except error: code = error.code
    assert_equal(code, 33)
    assert_equal(Capture[PilotFault].run(source)._err().value.code, 17)
