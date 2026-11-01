from context_product_contract_support import selected
from fp.algebra import OptionalFamily
from std.testing import assert_equal

def check[a: ImmOrigin,b: ImmOrigin](ref[a] first: Int,ref[b] second: Int) raises:
    var result = selected[OptionalFamily](Optional(Pointer(to=first)),Optional(Pointer(to=second))).get()
    comptime assert type_of(result) == Optional[Tuple[Pointer[Int,a],Pointer[Int,b]]]
    assert_equal(result.value()[0] == Pointer(to=first),True)
    assert_equal(result.value()[1] == Pointer(to=second),True)

def main() raises:
    var first = 17
    var second = 23
    check(first,second)
