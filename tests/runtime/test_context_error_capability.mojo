"""Mapping capability owns its selected layer without granting error recovery."""
from fp.algebra import ErrorRecovery, ErrorMapping, ApplicativeError, ResultFamily, IdentityFamily
from fp.data import Result, Ok, Err
from fp.functions import pipeline, OrElseContract, RedeemContract, RedeemWithContract
from error_mapping_support import Probe
from context_error_capability_support import Value, Effect, BorrowValue, BorrowEffect, Predicate, MakeError, recover, effect, changed_effect, observe, observe_effect, choose, positive, invalid, increment, increment_effect, changed_increment_effect, whole
from std.testing import assert_equal


def metadata():
    comptime I = Probe[String]
    comptime R = Result[Int,String]
    comptime assert conforms_to(I, ErrorMapping)
    comptime assert not conforms_to(I, ErrorRecovery)
    comptime assert not OrElseContract[I,R,Effect[String,String]].Compatible
    comptime assert not OrElseContract[I,R,Effect[String,Int]].Compatible
    comptime assert not RedeemContract[I,R,Value[Int],Value[String]].Compatible
    comptime assert not RedeemWithContract[I,R,Effect[Int,String],Effect[String,String]].Compatible
    comptime assert not RedeemWithContract[I,R,Effect[Int,Int],Effect[String,Int]].Compatible
    comptime assert OrElseContract[IdentityFamily,R,Effect[String,Int]].Compatible
    comptime assert RedeemContract[IdentityFamily,R,Value[Int],Value[String]].Compatible
    comptime assert RedeemWithContract[IdentityFamily,R,Effect[Int,Int],Effect[String,Int]].Compatible


def mapping() raises:
    comptime R = Result[Int,String]
    var mapped = pipeline[Probe[String]](R(Err(String("four")))).map_err(recover)
    comptime assert type_of(mapped).I == Probe[Int]
    assert_equal(mapped^.get()._err().value,4)
    var both = pipeline[Probe[String]](R(Ok(9))).map_both(increment,recover)
    comptime assert type_of(both).I == Probe[Int]
    assert_equal(both^.get()._ok().value,10)


def native_controls() raises:
    # The exact native callback shapes rejected under Probe remain valid when
    # Result owns the operation, including explicit reselection of its family.
    comptime R = Result[Int,String]
    assert_equal(pipeline[ResultFamily[String]](R(Err(String("old")))).recover(recover).get()._ok().value,3)
    assert_equal(pipeline(R(Err(String("old")))).or_else(effect).get()._ok().value,3)
    assert_equal(pipeline(R(Err(String("old")))).tap_err(observe).get()._err().value,"old")
    assert_equal(pipeline(R(Err(String("old")))).flat_tap_err(observe_effect).get()._err().value,"old")
    assert_equal(pipeline(R(Err(String("old")))).recover_if(choose,recover).get()._ok().value,3)
    assert_equal(pipeline(R(Err(String("old")))).or_else_if(choose,effect).get()._ok().value,3)
    assert_equal(pipeline(R(Ok(-1))).ensure(positive,invalid).get()._err().value,"invalid")
    assert_equal(pipeline(R(Err(String("old")))).redeem(increment,recover).get()._ok().value,3)
    var changed = pipeline(R(Err(String("old")))).redeem_with(changed_increment_effect,changed_effect)
    comptime assert type_of(changed).I == ResultFamily[Int]
    assert_equal(changed^.get()._ok().value,3)
    assert_equal(pipeline(R(Err(String("old")))).attempt_tap(whole).get()._err().value,"old")
    # Reading the carrier itself deliberately uses its own Result semantics.
    assert_equal(R(Err(String("old"))).or_else(changed_effect)._ok().value,3)


def intrinsic_library_controls() raises:
    # A family without either error capability retains the intrinsic Result
    # API; these are the exact library callback shapes used in the negatives.
    comptime R = Result[Int,String]
    assert_equal(pipeline[IdentityFamily](R(Err(String("old")))).recover(Value[String]()).get()._ok().value,7)
    var changed = pipeline[IdentityFamily](R(Err(String("old")))).or_else(Effect[String,Int]())
    comptime assert type_of(changed).I == ResultFamily[Int]
    assert_equal(changed^.get()._ok().value,7)
    assert_equal(pipeline[IdentityFamily](R(Err(String("old")))).tap_err(BorrowValue[String]()).get()._err().value,"old")
    assert_equal(pipeline[IdentityFamily](R(Err(String("old")))).flat_tap_err(BorrowEffect[String]()).get()._err().value,"old")
    assert_equal(pipeline[IdentityFamily](R(Err(String("old")))).recover_if(Predicate[String](),Value[String]()).get()._ok().value,7)
    assert_equal(pipeline[IdentityFamily](R(Err(String("old")))).or_else_if(Predicate[String](),Effect[String,String]()).get()._ok().value,7)
    assert_equal(pipeline[IdentityFamily](R(Ok(8))).ensure(Predicate[Int](),MakeError()).get()._ok().value,8)
    assert_equal(pipeline[IdentityFamily](R(Err(String("old")))).redeem(Value[Int](),Value[String]()).get()._ok().value,7)
    assert_equal(pipeline[IdentityFamily](R(Err(String("old")))).redeem_with(Effect[Int,String](),Effect[String,String]()).get()._ok().value,7)
    assert_equal(pipeline[IdentityFamily](R(Err(String("old")))).attempt_tap(BorrowEffect[R]()).get()._err().value,"old")


def main() raises:
    metadata()
    mapping()
    native_controls()
    intrinsic_library_controls()
