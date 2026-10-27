from context_map2_contract_support import forward, fluent, selected, legacy
from context_combination_admission_support import Add, OnceAdd, Stateful
from fp.algebra import IdentityFamily, OptionalFamily, ListFamily, ResultFamily, pure
from fp.effects import Reader, run
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def main() raises:
    assert_equal(forward[IdentityFamily](OnceAdd(), 1, 2),3)
    assert_equal(fluent[OptionalFamily](OnceAdd(), Optional(1),Optional(2)).value(),3)
    assert_equal(selected[ResultFamily[String]](OnceAdd(), pure[ResultFamily[String]](1),pure[ResultFamily[String]](2)).get()._ok().value,3)
    assert_equal(forward[ListFamily](Stateful(0),List[Int]([1,2]),List[Int]([10,20])),List[Int]([12,23,15,26]))
    assert_equal(selected[BoxMonad](Add(),pure[BoxMonad](1),pure[BoxMonad](2)).get().value,3)
    assert_equal(legacy[OptionalFamily](OnceAdd(),Optional(1),Optional(2)).value(),3)
    comptime G = Reader[Int]
    var pending = selected[G](OnceAdd(),pure[G](1),pure[G](2)).get()
    assert_equal(run[G](pending^,0),3)
