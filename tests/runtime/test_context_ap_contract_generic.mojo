from context_ap_contract_support import forward, fluent, selected, legacy, Consuming, Plus, Stateful, CopyOnce
from fp.algebra import IdentityFamily, OptionalFamily, ListFamily, ResultFamily, pure
from fp.functions import Identity
from fp.effects import Reader, run
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def main() raises:
    assert_equal(forward[IdentityFamily](Consuming(2),3),5)
    assert_equal(fluent[OptionalFamily](Optional(Plus(2)),Optional(3)).value(),5)
    assert_equal(selected[ResultFamily[String]](pure[ResultFamily[String]](Consuming(2)),pure[ResultFamily[String]](3)).get()._ok().value,5)
    assert_equal(forward[ListFamily](List[Plus]([Plus(1),Plus(2)]),List[Int]([10,20])),List[Int]([11,21,12,22]))
    assert_equal(selected[BoxMonad](pure[BoxMonad](Consuming(2)),pure[BoxMonad](3)).get().value,5)
    assert_equal(legacy[OptionalFamily](Optional(Consuming(2)),Optional(3)).value(),5)
    assert_equal(forward[ListFamily](List[Stateful]([Stateful(1),Stateful(2)]),List[Int]([10,20])),List[Int]([12,22,13,23]))
    assert_equal(fluent[ListFamily](List[CopyOnce]([CopyOnce(1)]),List[Int]([10,20])),List[Int]([11,21]))
    comptime G = Reader[Int]
    var pending = selected[G](pure[G](Consuming(2)),pure[G](3)).get()
    assert_equal(run[G](pending^,0),5)
    var different = selected[G](G.map(Identity[Consuming](),pure[G](Consuming(2))),pure[G](3)).get()
    assert_equal(run[G](different^,0),5)
