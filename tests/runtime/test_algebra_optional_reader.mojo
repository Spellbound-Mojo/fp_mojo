"""Nested native choices preserve the interpretation of each transformer layer."""
from fp.algebra import pure, map, flat_map
from fp.effects import Reader, OptionalT, run
from fp.callables import as_unary
from std.testing import assert_equal, assert_true

comptime Base = Reader[Int]
comptime Layer = OptionalT[Base]

def increment(var value:Int)->Int:
    return value+1

comptime Plain = Layer.Pure[Int]
comptime Mapped = Layer.Mapped[Plain,type_of(as_unary(increment))]
comptime Pair = Layer._Joined[Plain,Mapped]
comptime Tree = Layer._Joined[Pair,Mapped]

def choose(which:Int)->Tree:
    if which==0:
        return Layer._join_left[Pair,Mapped](Layer._join_left[Plain,Mapped](pure[Layer](10)))
    if which==1:
        return Layer._join_left[Pair,Mapped](Layer._join_right[Plain,Mapped](map[Layer](as_unary(increment),pure[Layer](20))))
    return Layer._join_right[Pair,Mapped](map[Layer](as_unary(increment),pure[Layer](30)))

def next_value(var value:Int)->Plain:
    return pure[Layer](value+10)


def main() raises:
    comptime assert Layer.Element[Tree] == Int
    comptime assert Base.Element[Tree] == Optional[Int]
    var environment=42
    var constructed=run[Base](pure[Layer](2),environment)
    assert_equal(constructed.take(),2)
    var mapped=run[Base](map[Layer](as_unary(increment),pure[Layer](2)),environment)
    assert_equal(mapped.take(),3)
    var bound=run[Base](flat_map[Layer](as_unary(next_value),pure[Layer](2)),environment)
    assert_equal(bound.take(),12)
    var skipped=run[Base](flat_map[Layer](as_unary(next_value),pure[Base](Optional[Int]())),environment)
    assert_true(not skipped)
    var expected:List[Int]=[10,21,31]
    for which in range(3):
        var value=run[Base](choose(which),environment)
        assert_equal(value.take(),expected[which])
    print("OptionalT Reader: construction, map, bind, absence, nested choices, layer metadata")
