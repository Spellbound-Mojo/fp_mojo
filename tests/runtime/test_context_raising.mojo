from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok
from std.testing import assert_equal
@fieldwise_init
struct ContextRaisingPilotFault(Movable):
    var code: Int
def select(value: Int) raises ContextRaisingPilotFault -> Bool: return value > 1
def transform(var value: Int) raises ContextRaisingPilotFault -> Int:
    if value == 3: raise ContextRaisingPilotFault(33)
    return value * 2
def source() raises ContextRaisingPilotFault -> Int: raise ContextRaisingPilotFault(17)
def main() raises:
    var code = 0
    try: _ = piped(List[Int]([1, 2, 3])).raising[ContextRaisingPilotFault]().filter(select).map(transform).get()
    except error: code = error.code
    assert_equal(code, 33)
    assert_equal(Capture[ContextRaisingPilotFault]().run(source)._err().value.code, 17)
