from fp.functions import pipeline as piped
from fp.data import Capture
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct ContextOwnershipSliceFault(Movable):
    var code: Int
@fieldwise_init
struct ContextOwnershipSliceOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1
def select(value: ContextOwnershipSliceOwner) -> Bool: return value.value > 0
def project(var value: ContextOwnershipSliceOwner) raises ContextOwnershipSliceFault -> Int:
    if value.value == 2: raise ContextOwnershipSliceFault(22)
    return value.value
def main() raises:
    var drops = ArcPointer(0)
    var values = List[ContextOwnershipSliceOwner]()
    for i in range(4): values.append(ContextOwnershipSliceOwner(i, drops))
    var code = 0
    try: _ = piped(values^).raising[ContextOwnershipSliceFault]().filter(select).map(project).get()
    except error: code = error.code
    assert_equal(code, 22)
    assert_equal(drops[], 4)
    var empty = List[ContextOwnershipSliceOwner]()
    var length = -1
    try:
        var untouched = piped(empty^).raising[ContextOwnershipSliceFault]().map(project).get()
        length = len(untouched)
    except error: code = error.code
    assert_equal(code, 22)
    assert_equal(length, 0)
    assert_equal(drops[], 4)
