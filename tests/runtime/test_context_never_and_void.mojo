from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct ContextNeverAndVoidSliceFault(Movable):
    var code: Int
def select(value: Int) raises Never -> Bool: return value > 0
def transform(var value: Int) raises Never -> Int: return value + 1
def source() raises Never -> Int: return 9
def void_source() raises Never: pass
def pure_void(): pass
def raising_void() raises ContextNeverAndVoidSliceFault: raise ContextNeverAndVoidSliceFault(19)
def main() raises:
    var output = piped(List[Int]([0, 1, 2])).filter(select).map(transform).get()
    assert_equal(output, List[Int]([2, 3]))
    assert_equal(Capture[Never]().run(source)._ok().value, 9)
    assert_equal(Capture[Never]().run(void_source).is_ok(), True)
    assert_equal(Capture[Never]().run(pure_void).is_ok(), True)
    assert_equal(Capture[ContextNeverAndVoidSliceFault]().run(raising_void)._err().value.code, 19)
