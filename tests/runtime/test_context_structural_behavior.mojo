"""Selected structural methods preserve their family shape and order."""
from fp.functions import pipeline
from fp.callables import Unary
from fp.data import Result,Ok,Err
from std.testing import assert_equal

@fieldwise_init
struct Plus(Unary,Copyable):
    var n:Int
    comptime Arg=Int
    comptime Out=Int
    def call(self,var value:Int)->Int: return value+self.n

def main() raises:
    assert_equal(pipeline(List[Int]([1,2])).fill(String("a")).get(),List[String](["a","a"]))
    assert_equal(pipeline(List[Int]([1,2,1])).replace(1,3).get(),List[Int]([3,2,3]))
    assert_equal(len(pipeline(List[Int]([1,2])).void().get()),2)
    assert_equal(pipeline(Optional(1)).tuple_left(String("x")).get().value()[0],"x")
    assert_equal(pipeline(Optional(1)).tuple_right(String("x")).get().value()[1],"x")
    assert_equal(pipeline(List[Optional[Int]]([Optional(1),Optional[Int](),Optional(3)])).compact().get(),List[Int]([1,3]))
    assert_equal(pipeline(Optional(Optional(2))).flatten().get().value(),2)
    assert_equal(pipeline(Result[Result[Int,String],String](Ok(Result[Int,String](Ok(3))))).flatten().get()._ok().value,3)
    assert_equal(pipeline(List[Plus]([Plus(1),Plus(10)])).ap(List[Int]([1,2])).get(),List[Int]([2,3,11,12]))
    assert_equal(len(pipeline(List[Plus]()).ap(List[Int]([1,2])).get()),0)
    assert_equal(Bool(pipeline(Optional[Plus]()).ap(Optional(1)).get()),False)
    assert_equal(pipeline(Result[Int,String](Err(String("source")))).fill(3).get()._err().value,"source")
    assert_equal(pipeline(Result[Result[Int,String],String](Err(String("outer")))).flatten().get()._err().value,"outer")
    assert_equal(pipeline(Result[Result[Int,String],String](Ok(Result[Int,String](Err(String("inner")))))).flatten().get()._err().value,"inner")
    assert_equal(Bool(pipeline(Optional(Optional[Int]())).compact().get()),False)
    assert_equal(pipeline(List[List[Int]]([List[Int]([1,2]),List[Int](),List[Int]([3])])).flatten().get(),List[Int]([1,2,3]))
