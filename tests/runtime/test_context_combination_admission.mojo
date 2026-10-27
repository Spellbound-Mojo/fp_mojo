"""Layer combination preserves Cartesian order and one lazy right invocation."""
from fp.algebra import ListFamily, map2_lazy
from fp.effects import OptionalT, ResultT
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal

from context_combination_admission_support import Add,Stateful,Right

def main() raises:
    comptime O=OptionalT[ListFamily]
    var calls=ArcPointer(Int(0))
    var right=List[Optional[Int]]([Optional(10),Optional[Int](),Optional(20)])
    var left=List[Optional[Int]]([Optional[Int](),Optional(1),Optional(2)])
    var optional=map2_lazy[O](Add(),left^,Right(right^,calls))
    assert_equal(calls[],1)
    assert_equal(len(optional),7)
    assert_equal(Bool(optional[0]),False)
    assert_equal(optional[1].value(),11)
    assert_equal(Bool(optional[2]),False)
    assert_equal(optional[3].value(),21)
    assert_equal(optional[4].value(),12)
    assert_equal(Bool(optional[5]),False)
    assert_equal(optional[6].value(),22)
    calls[]=0
    var stateful=map2_lazy[O](Stateful(0),List[Optional[Int]]([Optional(1),Optional(2)]),Right(List[Optional[Int]]([Optional(10),Optional[Int](),Optional(20)]),calls))
    assert_equal(calls[],1)
    assert_equal(stateful[0].value(),12)
    assert_equal(stateful[2].value(),23)
    assert_equal(stateful[3].value(),13)
    assert_equal(stateful[5].value(),24)
    calls[]=0
    var empty=map2_lazy[O](Add(),List[Optional[Int]]([Optional[Int]()]),Right(O.pure(7),calls))
    assert_equal(calls[],0)
    assert_equal(Bool(empty[0]),False)
    comptime R=ResultT[ListFamily,String]
    var errors=map2_lazy[R](Add(),List[Result[Int,String]]([Result[Int,String](Err(String("left"))),Result[Int,String](Ok(1)),Result[Int,String](Ok(2))]),Right(List[Result[Int,String]]([Result[Int,String](Ok(10)),Result[Int,String](Err(String("right"))),Result[Int,String](Ok(20))]),calls))
    assert_equal(calls[],1)
    assert_equal(len(errors),7)
    assert_equal(errors[0]._err().value,"left")
    assert_equal(errors[1]._ok().value,11)
    assert_equal(errors[2]._err().value,"right")
    assert_equal(errors[3]._ok().value,21)
    assert_equal(errors[4]._ok().value,12)
    assert_equal(errors[5]._err().value,"right")
    assert_equal(errors[6]._ok().value,22)
