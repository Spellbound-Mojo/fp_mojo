"""Direct Result flatten agrees with bind and selected family flatten."""
from fp.data import Result,Ok,Err
from fp.functions import pipeline,Identity
from std.testing import assert_equal

def flatten[T:Movable & Deinitable,E:Movable & Deinitable](var source:Result[Result[T,E],E])->Result[T,E]:
    return source^.flatten()

def number(value:Int)->String:return "ok "+String(value)
def failure(value:String)->String:return "err "+value

def describe(var value:Result[Int,String])->String:
    return value.fold(number,failure)

def main() raises:
    comptime Nested=Result[Result[Int,String],String]
    assert_equal(Nested(Ok(Result[Int,String](Ok(7)))).flatten().get_or(0),7)
    assert_equal(Nested(Ok(Result[Int,String](Err(String("inner"))))).flatten().swap().get_or(String()),"inner")
    assert_equal(Nested(Err(String("outer"))).flatten().swap().get_or(String()),"outer")
    assert_equal(flatten(Nested(Ok(Result[Int,String](Ok(9))))).get_or(0),9)
    for route in range(3):
        var nested=Nested(Ok(Result[Int,String](Ok(7)))) if route==0 else Nested(Ok(Result[Int,String](Err(String("inner"))))) if route==1 else Nested(Err(String("outer")))
        assert_equal(describe(nested.copy().flatten()),describe(nested.copy().flat_map(Identity[Result[Int,String]]())))
        assert_equal(describe(nested.copy().flatten()),describe(pipeline(nested^).flatten().get()))
    comptime Pure=Result[Int,Never]
    var pure=Result[Pure,Never](Ok(Pure(Ok(3)))).flatten()
    assert_equal(pure^.get_or(0),3)
    comptime Deep=Result[Nested,String]
    var deepest=Deep(Ok(Nested(Ok(Result[Int,String](Ok(5))))))
    assert_equal(deepest^.flatten().flatten().get_or(0),5)
