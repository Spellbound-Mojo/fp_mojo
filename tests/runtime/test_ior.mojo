"""Inclusive-or branch tables, laziness, matching and ordered traversal."""
import fp
from fp.data import Ior, Left, Right, Both, NonEmptyList
from fp.algebra import (IorFamily, IorValidationFamily, StringMonoid,
                        NonEmptyListSemigroup, ListFamily, map, flat_map,
                        map2_lazy, traverse)
from fp.callables import Binary, OnceThunk, MutableUnary
from fp.functions import piped, Identity
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

comptime IR = Ior[String, Int]
comptime IS = IorFamily[StringMonoid]
comptime IV = IorValidationFamily[StringMonoid]

def ir_case(kind: Int, value: Int, var issues: String) -> IR:
    if kind == 0: return Left(issues^)
    if kind == 1: return Right(value)
    return Both(issues^, value)

def ir_check(value: IR, present: Bool, issues: String, expected: Int) raises:
    assert_equal(value.isa[Left[String]](), not present)
    if value.isa[Left[String]](): assert_equal(value[Left[String]].value, issues)
    elif value.isa[Right[Int]]():
        assert_equal(issues, "")
        assert_equal(value[Right[Int]].value, expected)
    else:
        assert_equal(value[Both[String, Int]].left, issues)
        assert_equal(value[Both[String, Int]].right, expected)

@fieldwise_init
struct IRAdd(Binary):
    var calls: ArcPointer[Int]
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var first: Int, var second: Int) -> Int:
        self.calls[] += 1
        return first + second

@fieldwise_init
struct IRNext(OnceThunk):
    var calls: ArcPointer[Int]
    var kind: Int
    comptime Out = IR
    def call_once(deinit self) -> IR:
        self.calls[] += 1
        return ir_case(self.kind, 3, "b")

@fieldwise_init
struct IRStep(MutableUnary):
    var calls: ArcPointer[Int]
    var kind: Int
    comptime Arg = Int
    comptime Out = IR
    def call_mut(mut self, var arg: Int) -> IR:
        self.calls[] += 1
        return ir_case(self.kind, arg + 3, "b")

@fieldwise_init
struct IRVisit(MutableUnary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = IR
    def call_mut(mut self, var arg: Int) -> IR:
        self.calls[] += 1
        if arg < 0: return Left(String(arg))
        return Both(String(arg), arg * 10)

def ir_twice(value: Int) -> Int: return value * 2
def ir_drop(value: Int) -> NoneType: return None

def ir_nonempty(value: Int) -> Ior[NonEmptyList[Int], Int]:
    if value < 0: return Left(NonEmptyList(value))
    return Both(NonEmptyList(value), value * 10)

def main() raises:
    var calls = ArcPointer(0)
    var combines = ArcPointer(0)
    for a in range(3):
        var mapped = map[IS](ir_case(a, 2, "a"), ir_twice)
        ir_check(mapped, a != 0, "" if a == 1 else "a", 4)
        for b in range(3):
            calls[] = 0
            combines[] = 0
            var seq = map2_lazy[IS](ir_case(a, 2, "a"), IRNext(calls, b), IRAdd(combines))
            assert_equal(calls[], 0 if a == 0 else 1)
            assert_equal(combines[], 1 if a != 0 and b != 0 else 0)
            var issues = String("" if a == 1 else "a")
            if a != 0 and b != 1: issues += "b"
            ir_check(seq, a != 0 and b != 0, issues, 5)
            calls[] = 0
            var bound = flat_map[IS](ir_case(a, 2, "a"), IRStep(calls, b))
            assert_equal(calls[], 0 if a == 0 else 1)
            ir_check(bound, a != 0 and b != 0, issues, 5)
            calls[] = 0
            combines[] = 0
            var accumulated = map2_lazy[IV](ir_case(a, 2, "a"), IRNext(calls, b), IRAdd(combines))
            assert_equal(calls[], 1)
            assert_equal(combines[], 1 if a != 0 and b != 0 else 0)
            issues = "" if a == 1 else "a"
            if b != 1: issues += "b"
            ir_check(accumulated, a != 0 and b != 0, issues, 5)
    calls[] = 0
    var seq = traverse[IS, ListFamily](List[Int]([1, -2, 3, -4]), IRVisit(calls))
    assert_equal(calls[], 2)
    assert_equal(seq[Left[String]].value, "1-2")
    calls[] = 0
    var acc = traverse[IV, ListFamily](List[Int]([1, -2, 3, -4]), IRVisit(calls))
    assert_equal(calls[], 4)
    assert_equal(acc[Left[String]].value, "1-23-4")
    var success = traverse[IV, ListFamily](List[Int]([1, 2]), IRVisit(calls))
    assert_equal(success[Both[String, List[Int]]].left, "12")
    assert_equal(success[Both[String, List[Int]]].right, [10, 20])
    var empty = traverse[IV, ListFamily](List[Int](), IRVisit(calls))
    assert_equal(empty[Right[List[Int]]].value, List[Int]())
    comptime NE = IorValidationFamily[NonEmptyListSemigroup[Int]]
    var nonempty = traverse[NE, ListFamily](List[Int]([1, -2, 3]), ir_nonempty)
    assert_equal(nonempty[Left[NonEmptyList[Int]]].value.copy().into_list(), [1, -2, 3])
    var piped_value = piped(IR(Both(String("warning"), 5))).map[IS](ir_twice).get()
    ir_check(piped_value, True, "warning", 10)
    var description = fp.match(piped_value,
        lambda (left: Left[String]) -> String: "left: " + left.value,
        lambda (right: Right[Int]) -> String: "right: " + String(right.value),
        lambda (both: Both[String, Int]) -> String: both.left + ": " + String(both.right))
    assert_equal(description, "warning: 10")
    var same_types: Ior[Int, Int] = Both(7, 8)
    assert_true(same_types.isa[Both[Int, Int]]())
    var stored = same_types^.unwrap[Both[Int, Int]]()
    assert_equal(stored.left, 7)
    assert_equal(stored.right, 8)
    calls[] = 0
    var iterator = iter(List[Int]([99, 1, 2]))
    _ = iterator.__next__()
    var continued = traverse[IV, ListFamily](iterator^, IRVisit(calls))
    assert_equal(calls[], 2)
    assert_equal(continued[Both[String, List[Int]]].right, [10, 20])
    assert_equal(continued[Both[String, List[Int]]].left, "12")
    var piped_bound = piped(IR(Both(String("a"), 2))).flat_map[IS](IRStep(calls, 2)).get()
    ir_check(piped_bound, True, "ab", 5)
    ir_check(map[IS](IR(Left(String())), ir_twice), False, "", 0)
    ir_check(map[IS](IR(Both(String(), 0)), ir_twice), True, "", 0)
    var unit = map[IS](IR(Right(1)), ir_drop)
    assert_true(unit.isa[Right[NoneType]]())
    var kept_unit = map[IS](unit^, Identity[NoneType]())
    assert_true(kept_unit.isa[Right[NoneType]]())
    print("ior: ok")
