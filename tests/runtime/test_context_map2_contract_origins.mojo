from context_map2_contract_support import forward, selected, Keep, Raise
from fp.algebra import OptionalFamily
from std.testing import assert_equal

def check[o: ImmOrigin](ref[o] value: Int) raises:
    var result = forward[OptionalFamily](Keep[o](),Optional(Pointer(to=value)),Optional(2))
    comptime assert type_of(result) == Optional[Pointer[Int,o]]
    assert_equal(result.value() == Pointer(to=value),True)
    var caught = False
    try:
        _ = selected[OptionalFamily](Raise[o](Pointer(to=value)),Optional(1),Optional(2)).get()
    except error:
        comptime assert type_of(error) == Pointer[Int,o]
        caught = error == Pointer(to=value)
    assert_equal(caught,True)

def main() raises:
    var value = 17
    check(value)
