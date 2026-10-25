from fp.data import Capture
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct CaptureOwnershipOwnershipFault(Movable):
    var code: Int

@fieldwise_init
struct CaptureOwnershipOwnershipOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

def callback(mut state: Int, var value: CaptureOwnershipOwnershipOwner, /, var **options: CaptureOwnershipOwnershipOwner) raises CaptureOwnershipOwnershipFault -> CaptureOwnershipOwnershipOwner:
    state += value.value
    try:
        state += options["extra"].value + options["bonus"].value
    except _:
        raise CaptureOwnershipOwnershipFault(-999)
    if value.value < 0: raise CaptureOwnershipOwnershipFault(state)
    return value^

def main() raises:
    var drops = ArcPointer(0)
    var state = 0
    var pending = Capture[CaptureOwnershipOwnershipFault].mutable(state).take(CaptureOwnershipOwnershipOwner(2, drops)).kwargs(extra=CaptureOwnershipOwnershipOwner(3, drops), bonus=CaptureOwnershipOwnershipOwner(4, drops))
    assert_equal(drops[], 0)
    assert_equal(state, 0)
    var moved = pending^
    var result = moved^.run(callback)
    assert_equal(result._ok().value.value, 2)
    assert_equal(state, 9)
    assert_equal(drops[], 2)
    _ = result^
    assert_equal(drops[], 3)
    var error = Capture[CaptureOwnershipOwnershipFault].mutable(state).take(CaptureOwnershipOwnershipOwner(-2, drops)).kwargs(extra=CaptureOwnershipOwnershipOwner(3, drops), bonus=CaptureOwnershipOwnershipOwner(4, drops)).run(callback)
    assert_equal(error._err().value.code, 14)
    assert_equal(drops[], 6)
    var unused = Capture[CaptureOwnershipOwnershipFault].mutable(state).take(CaptureOwnershipOwnershipOwner(2, drops)).kwargs(extra=CaptureOwnershipOwnershipOwner(3, drops), bonus=CaptureOwnershipOwnershipOwner(4, drops))
    _ = unused^
    assert_equal(drops[], 9)
    assert_equal(state, 14)
