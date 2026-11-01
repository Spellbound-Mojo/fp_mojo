from fp.iteration import fold_left, iterated
from fp.callables import Binary, MutableBinary
from std.testing import assert_equal
@fieldwise_init
struct Shared(Binary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    var calls:Int
    def call(self,var a:Int,var b:Int)->Int: return a+b
@fieldwise_init
struct Mutable(MutableBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    var calls:Int
    def call_mut(mut self,var a:Int,var b:Int)->Int:
        self.calls+=1
        return a+b+self.calls
@fieldwise_init
struct Dual(Binary,MutableBinary):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    var calls:Int
    def call(self,var a:Int,var b:Int)->Int: return a+b
    def call_mut(mut self,var a:Int,var b:Int)->Int:
        self.calls+=1
        return a+b+self.calls

@fieldwise_init
struct ImplicitDual(Binary,MutableBinary,ImplicitlyCopyable):
    comptime First=Int
    comptime Second=Int
    comptime Out=Int
    var calls:Int
    def call(self,var a:Int,var b:Int)->Int: return a+b
    def call_mut(mut self,var a:Int,var b:Int)->Int:
        self.calls+=1
        return a+b+self.calls

def main() raises:
    var shared=Shared(0)
    assert_equal(fold_left([1,2],0,shared),3)
    assert_equal(fold_left([1,2],0,shared),3)
    assert_equal(fold_left([1,2],0,shared^),3)
    assert_equal(fold_left([1,2],0,Mutable(0)),6)
    var dual=Dual(0)
    assert_equal(fold_left([1,2],0,dual),3)
    assert_equal(fold_left([1,2],0,dual^),6)
    assert_equal(fold_left([1,2],0,Dual(0)),6)
    var copied=ImplicitDual(0)
    assert_equal(fold_left([1,2],0,copied),3)
    assert_equal(iterated([1,2]).fold_left(copied,0),3)
    assert_equal(iterated([1,2]).fold_left(copied^,0),6)
    assert_equal(iterated([1,2]).fold_left(ImplicitDual(0),0),6)
