from context_if_contract_support import forward, fluent, selected, Factory, Once, legacy_forward, legacy_fluent
from fp.algebra import IdentityFamily, OptionalFamily, ListFamily, ResultFamily, pure
from fp.effects import Reader, run
from fp.functions import piped
from fp.data import Result, Ok
from algebra_support.box import BoxMonad
from std.testing import assert_equal

def main() raises:
    assert_equal(forward[IdentityFamily](Once[IdentityFamily](1), Once[IdentityFamily](2), True), 1)
    assert_equal(forward[OptionalFamily](Once[OptionalFamily](1), Once[OptionalFamily](2), Optional(False)).value(), 2)
    assert_equal(fluent[OptionalFamily](Factory[OptionalFamily](1), Factory[OptionalFamily](2), Optional(True)).value(), 1)
    assert_equal(selected[OptionalFamily](Factory[OptionalFamily](1), Factory[OptionalFamily](2), Optional(True)).get().value(), 1)
    assert_equal(forward[ListFamily](Factory[ListFamily](1), Factory[ListFamily](2), List[Bool]([False, True])), List[Int]([2,1]))
    assert_equal(selected[BoxMonad](Factory[BoxMonad](1), Factory[BoxMonad](2), pure[BoxMonad](False)).get().value, 2)
    comptime D = Reader[Int]
    var pending = selected[D](Once[D](1), Once[D](2), pure[D](True)).get()
    assert_equal(run[D](pending^, 0), 1)
    assert_equal(piped(Optional(True)).if_effect(Once[OptionalFamily](3), Once[OptionalFamily](4)).get().value(), 3)
    assert_equal(piped(Result[Bool,String](Ok(False))).if_effect(Once[ResultFamily[String]](3), Once[ResultFamily[String]](4)).get()._ok().value, 4)
    assert_equal(legacy_forward[OptionalFamily](Once[OptionalFamily](5), Once[OptionalFamily](6), Optional(True)).value(), 5)
    assert_equal(legacy_fluent[OptionalFamily](Once[OptionalFamily](5), Once[OptionalFamily](6), Optional(False)).value(), 6)
