"""Fill transfers a replacement through single-call families and copies for repetition."""
from fp.data import Result,Ok,Err
from fp.functions import pipeline,piped
from fp.algebra import ResultFamily,OptionalFamily,IdentityFamily
from fp.effects import Reader,run
from std.testing import assert_equal

@fieldwise_init
struct Box(Movable):
    var value:Int

def generic[A:Movable & Deinitable,B:Movable & Deinitable,X:Movable & Deinitable](var source:Result[A,X],var value:B)->Result[B,X]:
    return pipeline(source^).fill(value^).get()

def main() raises:
    var selected=pipeline(Result[Int,String](Ok(1))).fill(Box(7)).get()
    assert_equal(selected^.get_or(Box(0)).value,7)
    var legacy=piped(Result[Int,String](Ok(1))).fill(Box(8)).get()
    assert_equal(legacy^.get_or(Box(0)).value,8)
    var explicit=piped(Result[Int,String](Ok(1))).fill[ResultFamily[String]](Box(9)).get()
    assert_equal(explicit^.get_or(Box(0)).value,9)
    var optional=pipeline(Optional(1)).fill(Box(10)).get()
    assert_equal(optional.value().value,10)
    var output=generic(Result[Int,String](Ok(1)),Box(11))
    assert_equal(output^.get_or(Box(0)).value,11)
    assert_equal(pipeline(List[Int]([1,2])).fill(7).get(),[7,7])
    var identity=pipeline(1).fill(Box(12)).get()
    assert_equal(identity.value,12)
    comptime R=Reader[Int]
    var pending=pipeline[R](R.pure(1)).fill(Box(13)).get()
    assert_equal(run[R](pending^,0).value,13)
    var legacy_optional=piped(Optional(1)).fill(Box(14)).get()
    assert_equal(legacy_optional.value().value,14)
    var explicit_optional=piped(Optional(1)).fill[OptionalFamily](Box(15)).get()
    assert_equal(explicit_optional.value().value,15)
    var selected_family=pipeline[ResultFamily[String]](Result[Int,String](Ok(1))).fill(Box(16)).get()
    assert_equal(selected_family^.get_or(Box(0)).value,16)
