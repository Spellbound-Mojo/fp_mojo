from fp.functions import piped
from fp.data import attempt
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct SliceFault(Movable):
    var code: Int
def generic[A: Movable & Deinitable, R: Movable & Deinitable, //, F: def(var A) -> R](function: F, var value: Optional[A]) -> Optional[R]:
    return piped(value^).map(function).get()
def generic_raising[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: def(var A) raises E -> R](function: F, var value: Optional[A]) raises E -> Optional[R]:
    return piped(value^).map(function).get()
def generic_capture[R: Movable & Deinitable, E: Movable & Deinitable, //, F: def() raises E -> R](function: F) -> Result[R, E]:
    return attempt(function)
def main() raises:
    var bias = 2
    def transform(var value: Int) {bias} -> Int: return value + bias
    def raising(var value: Int) raises SliceFault {bias} -> Int: raise SliceFault(value + bias)
    def source() raises SliceFault {bias} -> Int: raise SliceFault(bias)
    var result = generic(transform, Optional(3))
    assert_equal(result.take(), 5)
    var code = 0
    try: _ = generic_raising(raising, Optional(3))
    except error: code = error.code
    assert_equal(code, 5)
    assert_equal(generic_capture(source)._err().value.code, 2)
