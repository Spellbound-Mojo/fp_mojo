from context_ap_contract_support import forward, selected, View
from fp.algebra import OptionalFamily
from fp.callables import OnceUnary
from std.testing import assert_equal

def check[o: ImmOrigin](ref[o] value: Int) raises:
    var result = forward[OptionalFamily](Optional(View[o](False)),Optional(Pointer(to=value)))
    comptime assert type_of(result) == Optional[Pointer[Int,o]]
    assert_equal(result.value() == Pointer(to=value),True)
    var caught = False
    try:
        _ = selected[OptionalFamily](Optional(View[o](True)),Optional(Pointer(to=value))).get()
    except error:
        comptime assert type_of(error) == Pointer[Int,o]
        caught = error == Pointer(to=value)
    assert_equal(caught,True)

def main() raises:
    var value = 17
    check(value)
