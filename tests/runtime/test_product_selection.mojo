"""Applicative selection retains policy, shape and public generic forwarding."""
from fp.algebra import Applicative, ProductLeftContract, ProductRightContract, product_l, product_r, IdentityFamily, OptionalFamily, ListFamily, ResultFamily, ValidationFamily, StringMonoid, pure
from fp.functions import pipeline, Pipeline
from fp.data import Result, Ok, Err
from algebra_support.box import BoxMonad
from std.testing import assert_equal


def keep_left[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var first: V, var second: W
) raises ProductLeftContract[I,V,W].Error -> ProductLeftContract[I,V,W].Out where ProductLeftContract[I,V,W].Compatible:
    return product_l[I](first^,second^)


def keep_right[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var first: V, var second: W
) raises ProductRightContract[I,V,W].Error -> Pipeline[ProductRightContract[I,V,W].Family,ProductRightContract[I,V,W].Out] where ProductRightContract[I,V,W].Compatible:
    return pipeline[I](first^).product_r(second^)


def selected_left[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var first: V, var second: W
) raises ProductLeftContract[I,V,W].Error -> Pipeline[ProductLeftContract[I,V,W].Family,ProductLeftContract[I,V,W].Out] where ProductLeftContract[I,V,W].Compatible:
    return pipeline[I](first^).product_l(second^)


def free_right[I: Applicative, V: Movable & Deinitable, W: Movable & Deinitable](var first: V, var second: W
) raises ProductRightContract[I,V,W].Error -> ProductRightContract[I,V,W].Out where ProductRightContract[I,V,W].Compatible:
    return product_r[I](first^,second^)


def main() raises:
    assert_equal(selected_left[OptionalFamily](Optional(7),Optional(String("right"))).get().value(),7)
    assert_equal(free_right[OptionalFamily](Optional(7),Optional(String("right"))).value(),"right")
    assert_equal(keep_left[IdentityFamily](7,String("unused")),7)
    assert_equal(keep_right[IdentityFamily](7,String("kept")).get(),"kept")
    assert_equal(product_r[OptionalFamily](Optional(1),Optional(String("right"))).value(),"right")
    assert_equal(pipeline(Optional(1)).product_l(Optional(String("right"))).get().value(),1)
    assert_equal(Bool(pipeline(Optional[Int]()).product_r(Optional(2)).get()),False)
    assert_equal(Bool(pipeline(Optional(1)).product_l(Optional[Int]()).get()),False)
    assert_equal(pipeline(List[Int]([1,2])).product_l(List[Int]([10,20,30])).get(),List[Int]([1,1,1,2,2,2]))
    assert_equal(pipeline(List[Int]([1,2])).product_r(List[Int]([10,20,30])).get(),List[Int]([10,20,30,10,20,30]))
    assert_equal(len(pipeline(List[Int]([1,2])).product_l(List[Int]()).get()),0)
    assert_equal(len(pipeline(List[Int]()).product_r(List[Int]([10,20])).get()),0)
    assert_equal(keep_right[BoxMonad](pure[BoxMonad](1),pure[BoxMonad](2)).get().value,2)
    comptime R = Result[Int,String]
    comptime V = ValidationFamily[StringMonoid]
    comptime for left_ok in range(2):
        comptime for right_ok in range(2):
            var left: R = Ok(7) if left_ok else Err(String("left;"))
            var right: R = Ok(9) if right_ok else Err(String("right;"))
            var normal = pipeline(left.copy()).product_r(right.copy()).get()
            var accumulated_left = pipeline[V](left.copy()).product_l(right.copy()).get()
            var accumulated_right = pipeline[V](left^).product_r(right^).get()
            if left_ok and right_ok:
                assert_equal(normal._ok().value,9)
                assert_equal(accumulated_left._ok().value,7)
                assert_equal(accumulated_right._ok().value,9)
            else:
                assert_equal(normal._err().value,"right;" if left_ok else "left;")
                var expected = String("" if left_ok else "left;") + ("" if right_ok else "right;")
                assert_equal(accumulated_left._err().value,expected)
                assert_equal(accumulated_right._err().value,expected)
    var calls = 0
    def constructed() {mut calls} -> Optional[Int]:
        calls += 1
        return Optional(9)
    _ = pipeline(Optional[Int]()).product_r(constructed()).get()
    assert_equal(calls,1)
    _ = pipeline(Optional[Int]()).followed_by(constructed).get()
    assert_equal(calls,1)
