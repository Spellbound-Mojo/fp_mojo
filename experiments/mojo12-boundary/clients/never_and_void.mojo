from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct SliceFault(Movable):
    var code: Int
def select(value: Int) raises Never -> Bool: return value > 0
def transform(var value: Int) raises Never -> Int: return value + 1
def source() raises Never -> Int: return 9
def void_source() raises Never: pass
def pure_void(): pass
def raising_void() raises SliceFault: raise SliceFault(19)
def main() raises:
    var output = piped(List[Int]([0, 1, 2])).filter(select).map(transform).get()
    assert_equal(output, List[Int]([2, 3]))
    assert_equal(attempt(source)._ok().value, 9)
    assert_equal(attempt(void_source).is_ok(), True)
    assert_equal(attempt(pure_void).is_ok(), True)
    assert_equal(Capture[SliceFault].run(raising_void)._err().value.code, 19)
