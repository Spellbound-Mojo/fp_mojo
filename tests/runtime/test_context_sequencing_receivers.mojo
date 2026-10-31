"""Checked sequencing wrappers admit actual receivers and preserve execution."""
from fp.algebra import OptionalFamily, ListFamily
from fp.algebra.contracts import FlatTapContract, FlatPairWithContract, BeforeContract, FollowedByContract
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal
from context_sequencing_receiver_support import MissingBorrow, MissingThunk, checked_flat_tap, checked_flat_pair_with, checked_before, checked_followed_by
from test_context_sequencing_contracts import Project, Create, Branches, OwnedFactory, OwnedProjection, Token, Raised


def main() raises:
    comptime assert FlatTapContract[OptionalFamily,Optional[Int],MissingBorrow].Compatible
    comptime assert FlatPairWithContract[OptionalFamily,Optional[Int],MissingBorrow].Compatible
    comptime assert BeforeContract[OptionalFamily,Optional[Int],MissingThunk].Compatible
    comptime assert FollowedByContract[OptionalFamily,Optional[Int],MissingThunk].Compatible
    comptime assert not FlatTapContract[OptionalFamily,Optional[Int],MissingBorrow].ReceiverCompatible
    comptime assert not FlatPairWithContract[OptionalFamily,Optional[Int],MissingBorrow].InvocationCompatible
    comptime assert not BeforeContract[OptionalFamily,Optional[Int],MissingThunk].ReceiverCompatible
    comptime assert not FollowedByContract[OptionalFamily,Optional[Int],MissingThunk].InvocationCompatible
    var calls = ArcPointer(0)
    assert_equal(checked_flat_tap[OptionalFamily](Optional(3),Project[OptionalFamily](calls)).value(),3)
    assert_equal(checked_flat_pair_with[OptionalFamily](Optional(3),Project[OptionalFamily](calls)).value(),(3,13))
    assert_equal(checked_before[OptionalFamily](Optional(3),Create[OptionalFamily](calls)).value(),3)
    assert_equal(checked_followed_by[OptionalFamily](Optional(3),Create[OptionalFamily](calls)).value(),7)
    assert_equal(calls[],4)
    assert_equal(checked_before[ListFamily](List[Int]([1,2]),Branches(0)),[1,1,2,2])
    assert_equal(checked_followed_by[ListFamily](List[Int]([1,2]),Branches(0)),[1,11,2,12])
    var drops = ArcPointer(0)
    var pair = checked_flat_pair_with[OptionalFamily](Optional(Token(5,drops)),OwnedProjection(Token(7,drops)))
    assert_equal(pair.value()[0].value,5)
    assert_equal(pair.value()[1].value,7)
    _ = pair^
    assert_equal(drops[],2)
    assert_equal(checked_before[OptionalFamily](Optional(3),OwnedFactory[False](Token(7,drops),calls)).value(),3)
    assert_equal(drops[],3)
    assert_equal(checked_followed_by[OptionalFamily](Optional(3),OwnedFactory[False](Token(7,drops),calls)).value(),7)
    assert_equal(drops[],4)
    var code = 0
    try: _ = checked_before[OptionalFamily](Optional(3),OwnedFactory[True](Token(7,drops),calls))
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,717)
    assert_equal(drops[],5)
    comptime R = Reader[Int]
    calls[] = 0
    var deferred = checked_flat_pair_with[R](R.pure(3),Project[R](calls))
    assert_equal(calls[],0)
    assert_equal(run[R](deferred^,0),(3,13))
    assert_equal(calls[],1)
    comptime assert BeforeContract[R,R.Pure[Int],Raised[R]].Error == Never
    var failed = checked_before[R](R.pure(3),Raised[R]())
    try: _ = run[R](failed^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,713)
