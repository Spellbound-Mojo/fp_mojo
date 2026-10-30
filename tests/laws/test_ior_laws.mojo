"""Ior functor, coherent sequential monad and accumulating applicative laws."""
from fp.data import Ior, Left, Right, Both
from fp.algebra import IorFamily, IorValidationFamily, StringMonoid, map, flat_map, map2, ap
from fp.callables import Unary, Binary
from fp.functions import Identity
from std.testing import assert_equal

comptime ILR = Ior[String, Int]
comptime ILM = IorFamily[StringMonoid]
comptime ILV = IorValidationFamily[StringMonoid]

def il_value(kind: Int, value: Int, var warning: String) -> ILR:
    if kind == 0: return Left(warning^)
    if kind == 1: return Right(value)
    return Both(warning^, value)

def il_equal(a: ILR, b: ILR) raises:
    assert_equal(a.isa[Left[String]](), b.isa[Left[String]]())
    assert_equal(a.isa[Right[Int]](), b.isa[Right[Int]]())
    if a.isa[Left[String]](): assert_equal(a[Left[String]].value, b[Left[String]].value)
    elif a.isa[Right[Int]](): assert_equal(a[Right[Int]].value, b[Right[Int]].value)
    else:
        assert_equal(a[Both[String, Int]].left, b[Both[String, Int]].left)
        assert_equal(a[Both[String, Int]].right, b[Both[String, Int]].right)

@fieldwise_init
struct ILStep(Unary, Copyable):
    var kind: Int
    var label: String
    var amount: Int
    comptime Arg = Int
    comptime Out = ILR
    def call(self, var arg: Int) -> ILR: return il_value(self.kind, arg + self.amount, self.label.copy())

@fieldwise_init
struct ILComposed(Unary):
    var f: ILStep
    var g: ILStep
    comptime Arg = Int
    comptime Out = ILR
    def call(self, var arg: Int) -> ILR: return flat_map[ILM](self.f.call(arg), self.g.copy())

@fieldwise_init
struct ILPure(Unary, Copyable, Defaultable):
    comptime Arg = Int
    comptime Out = ILR
    def call(self, var arg: Int) -> ILR: return ILM.pure(arg)

@fieldwise_init
struct ILAdd(Binary, Copyable, Defaultable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var first: Int, var second: Int) -> Int: return first + second

def il_twice(value: Int) -> Int: return value * 2
def il_plus(value: Int) -> Int: return value + 1
def il_composed(value: Int) -> Int: return value * 2 + 1

def main() raises:
    for a in range(3):
        var original = il_value(a, 5, "a")
        il_equal(map[ILM](original.copy(), Identity[Int]()), original)
        var mapped = map[ILM](original.copy(), il_twice)
        il_equal(map[ILM](mapped^, il_plus), map[ILM](original.copy(), il_composed))
        il_equal(flat_map[ILM](original.copy(), ILPure()), original)
        il_equal(ap[ILM](Ior[String, Identity[Int]](Right(Identity[Int]())), original.copy()), original)
        il_equal(ap[ILV](Ior[String, Identity[Int]](Right(Identity[Int]())), original.copy()), original)
        il_equal(flat_map[ILM](ILM.pure(5), ILStep(a, "f", 3)), ILStep(a, "f", 3).call(5))
        for b in range(3):
            for c in range(3):
                var f = ILStep(b, "b", 3)
                var g = ILStep(c, "c", 7)
                var bound = flat_map[ILM](original.copy(), f.copy())
                il_equal(flat_map[ILM](bound^, g.copy()), flat_map[ILM](original.copy(), ILComposed(f^, g^)))
                var second = il_value(b, 3, "b")
                var third = il_value(c, 7, "c")
                var left = map2[ILV](ILAdd(), original.copy(), second.copy())
                var right = map2[ILV](ILAdd(), second^, third.copy())
                il_equal(map2[ILV](ILAdd(), left^, third^), map2[ILV](ILAdd(), original.copy(), right^))
    print("ior laws: ok")
