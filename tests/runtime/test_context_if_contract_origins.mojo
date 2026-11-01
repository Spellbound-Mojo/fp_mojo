from context_if_contract_support import forward, selected, Once, PointerFactory, PointerFailure, MappedReader
from fp.algebra import OptionalFamily, pure
from fp.effects import Reader, run
from std.testing import assert_equal

def payloads[o: ImmOrigin](ref[o] value: Int) raises:
    var first = PointerFactory[o](Pointer(to=value))
    var second = PointerFactory[o](Pointer(to=value))
    var result = forward[OptionalFamily](first^, second^, Optional(True))
    comptime assert type_of(result) == Optional[Pointer[Int,o]]
    assert_equal(result.value() == Pointer(to=value), True)

def failures[o: ImmOrigin](ref[o] error: Int) raises:
    var caught = False
    try:
        _ = selected[OptionalFamily](PointerFailure[o](Pointer(to=error)), Once[OptionalFamily](3), Optional(True)).get()
    except raised:
        comptime assert type_of(raised) == Pointer[Int,o]
        caught = raised == Pointer(to=error)
    assert_equal(caught, True)

def main() raises:
    var value = 21
    payloads(value)
    failures(value)
    comptime G = Reader[Int]
    var pending = selected[G](Once[G](3), MappedReader(), pure[G](False)).get()
    assert_equal(run[G](pending^, 0), 9)
    var first = selected[G](Once[G](3), MappedReader(), pure[G](True)).get()
    assert_equal(run[G](first^, 0), 3)
