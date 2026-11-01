from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct SliceFault(Movable):
    var code: Int
@fieldwise_init
struct SliceOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
def select(value: SliceOwner) -> Bool: return value.value > 0
def project(var value: SliceOwner) raises SliceFault -> Int:
    if value.value == 2: raise SliceFault(22)
    return value.value
def main() raises:
    var drops = ArcPointer(0)
    var values = List[SliceOwner]()
    for i in range(4): values.append(SliceOwner(i, drops))
    var code = 0
    try: _ = piped(values^).raising[SliceFault]().filter(select).map(project).get()
    except error: code = error.code
    assert_equal(code, 22)
    assert_equal(drops[], 4)
    var empty = List[SliceOwner]()
    var length = -1
    try:
        var untouched = piped(empty^).raising[SliceFault]().map(project).get()
        length = len(untouched)
    except error: code = error.code
    assert_equal(code, 22)
    assert_equal(length, 0)
    assert_equal(drops[], 4)
