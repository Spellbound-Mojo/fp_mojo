from context_product_contract_support import forward, fluent, selected, legacy
from fp.algebra import IdentityFamily, OptionalFamily, ListFamily, ResultFamily, pure
from fp.effects import Reader, run
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def main() raises:
    var first = forward[IdentityFamily](1,String("two"))
    assert_equal(first[0],1)
    assert_equal(first[1],"two")
    assert_equal(fluent[OptionalFamily](Optional(1),Optional(2)).value(),(1,2))
    assert_equal(selected[ResultFamily[String]](pure[ResultFamily[String]](1),pure[ResultFamily[String]](2)).get()._ok().value,(1,2))
    assert_equal(forward[ListFamily](List[Int]([1,2]),List[Int]([10,20])),List[Tuple[Int,Int]]([(1,10),(1,20),(2,10),(2,20)]))
    assert_equal(selected[BoxMonad](pure[BoxMonad](1),pure[BoxMonad](2)).get().value,(1,2))
    assert_equal(legacy[OptionalFamily](Optional(1),Optional(2)).value(),(1,2))
    comptime G = Reader[Int]
    var pending = selected[G](pure[G](1),pure[G](2)).get()
    assert_equal(run[G](pending^,0),(1,2))
