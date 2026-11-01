"""Mixed folds admit register and memory arguments and results without annotations."""
from fp.data import Result,Ok,Err
from fp.callables import Unary,BorrowCallable
from std.testing import assert_equal

@fieldwise_init
struct Handler[A:Movable & Deinitable,R:Copyable & Deinitable](Unary,BorrowCallable):
    comptime Arg=Self.A
    comptime Payload=Self.A
    comptime Out=Self.R
    comptime Result=Self.R
    var output:Self.R
    def call(self,var value:Self.A)->Self.R: return self.output.copy()
    def invoke(self,ref value:Self.A)->Self.R: return self.output.copy()

def read_int(value:Int)->Int: return value+10
def read_text(value:Int)->String: return String(value)
def read_size(value:String)->Int: return value.byte_length()
def read_copy(value:String)->String: return value.copy()
def own_int(var value:Int)->Int: return value+10
def own_text(var value:Int)->String: return String(value)
def own_size(var value:String)->Int: return value.byte_length()
def own_copy(var value:String)->String: return value^
def quiet(value:String) raises Never -> String: return value.copy()
def checked(var value:String) raises Int -> String:
    if not value: raise 7
    return value^

def main() raises:
    var ints=Result[Int,Int](Ok(4))
    var strings=Result[String,String](Err(String("four")))
    var a=Handler[Int,Int](100)
    var b=Handler[Int,String](String("stored"))
    var c=Handler[String,Int](100)
    var d=Handler[String,String](String("stored"))
    assert_equal(ints.fold(read_int,a),14)
    assert_equal(ints.fold(a,read_int),100)
    assert_equal(ints.fold(read_text,b),"4")
    assert_equal(ints.fold(b,read_text),"stored")
    assert_equal(strings.fold(c,read_size),4)
    assert_equal(strings.fold(read_size,c),100)
    assert_equal(strings.fold(d,read_copy),"four")
    assert_equal(strings.fold(read_copy,d),"stored")
    assert_equal(strings.fold(d,quiet),"four")
    assert_equal(strings.is_err(),True)
    var p0:def(Int) thin -> Int=read_int
    var p1:def(Int) thin -> String=read_text
    var p2:def(String) thin -> Int=read_size
    var p3:def(String) thin -> String=read_copy
    assert_equal(ints.fold(p0,a),14)
    assert_equal(ints.fold(p1,b),"4")
    assert_equal(strings.fold(c,p2),4)
    assert_equal(strings.fold(d,p3),"four")
    assert_equal(Result[Int,Int](Ok(4)).fold_owned(own_int,a),14)
    assert_equal(Result[Int,Int](Ok(4)).fold_owned(own_text,b),"4")
    assert_equal(Result[String,String](Err(String("four"))).fold_owned(c,own_size),4)
    assert_equal(strings^.fold_owned(d,own_copy),"four")
    var p4:def(var String) thin -> String=own_copy
    assert_equal(Result[String,String](Err(String("four"))).fold_owned(d,p4),"four")
    assert_equal(Result[Int,Int](Ok(4)).fold(read_int,Handler[Int,Int](100)),14)
    assert_equal(Result[Int,Int](Err(4)).fold(Handler[Int,String](String("stored")),read_text),"4")
    assert_equal(Result[String,String](Err(String("four"))).fold_owned(Handler[String,String](String("stored")),own_copy),"four")
    var error_value=0
    try:
        _=Result[String,String](Err(String())).fold_owned(d,checked)
    except error:
        comptime assert type_of(error)==Int
        error_value=error
    assert_equal(error_value,7)
