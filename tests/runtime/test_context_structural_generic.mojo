"""Structural operations retain their types through generic forwarding."""
from fp.functions import pipeline
from fp.data import Result,Ok,Err
from std.testing import assert_equal
from fp.callables import UnaryContract
from test_context_structural_behavior import Plus

def filling[A:Movable & Deinitable,B:Copyable & Deinitable,X:Movable & Deinitable](var source:Result[A,X],var value:B) -> Result[B,X]:
    return pipeline(source^).fill(value^).get()
def compacting[A:Movable & Deinitable](var source:List[Optional[A]]) -> List[A]:
    return pipeline(source^).compact().get()
def flattening[A:Movable & Deinitable,X:Movable & Deinitable](var source:Result[Result[A,X],X]) -> Result[A,X]:
    return pipeline(source^).flatten().get()
def applying[F:UnaryContract & Movable & Deinitable,X:Movable & Deinitable](var source:Result[F,X],var values:Result[F.Arg,X]) raises F.Error -> Result[F.Out,X]:
    return pipeline(source^).ap(values^).get()
def main() raises:
    assert_equal(filling(Result[Int,String](Ok(1)),String("x"))._ok().value,"x")
    assert_equal(compacting(List[Optional[Int]]([Optional(1)]))[0],1)
    assert_equal(flattening(Result[Result[Int,String],String](Ok(Result[Int,String](Ok(2)))))._ok().value,2)
    assert_equal(applying(Result[Plus,String](Ok(Plus(2))),Result[Int,String](Ok(3)))._ok().value,5)
