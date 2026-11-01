from fp.callables import RepeatableUnary,UnaryContract,OnceUnary,MutableUnary,call_once,call_repeated
from fp.effects.state import _MapFirst
from fp.effects.writer import _MapValue,_Censor
from std.memory import ArcPointer
from std.testing import assert_equal
from std.builtin.rebind import rebind_var

@fieldwise_init
struct Owner(Movable):
    var id:Int
    var trace:ArcPointer[String]
    def __deinit__(deinit self):self.trace[]+=String(self.id)

@fieldwise_init
struct Once(OnceUnary):
    var capture:Owner
    var fail:Bool
    comptime Arg=Owner
    comptime Out=Owner
    comptime Error=Int
    def call_once(deinit self,var value:Owner) raises Int ->Owner:
        self.capture.trace[]+="c"
        if self.fail:raise 71
        return value^

@fieldwise_init
struct Mutable(MutableUnary):
    var capture:Owner
    var fail:Bool
    var calls:Int
    comptime Arg=Owner
    comptime Out=Owner
    comptime Error=Int
    def call_mut(mut self,var value:Owner) raises Int ->Owner:
        self.calls+=1
        self.capture.trace[]+="m"+String(self.calls)
        if self.fail:raise 72
        return value^

def exercise_once[C:UnaryContract & Movable & Deinitable](var mapped:C,trace:ArcPointer[String]):
    comptime assert C.Arg==Tuple[Owner,Owner] and C.Out==Tuple[Owner,Owner] and C.Error==Int
    try:
        var result=call_once(mapped^,rebind_var[C.Arg](Tuple(Owner(1,trace),Owner(2,trace))))
        _=result^
    except error:
        comptime assert type_of(error)==Int
        trace[]+="e"


def exercise_mut[C:UnaryContract & Movable & Deinitable](var mapped:C,trace:ArcPointer[String]):
    comptime assert C.Arg==Tuple[Owner,Owner] and C.Out==Tuple[Owner,Owner] and C.Error==Int
    comptime assert RepeatableUnary[C]
    for _ in range(2):
        try:
            var result=call_repeated(mapped,rebind_var[C.Arg](Tuple(Owner(1,trace),Owner(2,trace))))
            _=result^
        except error:
            comptime assert type_of(error)==Int
            trace[]+="e"
    _=mapped^


def exercise[mutable:Bool,C:UnaryContract & Movable & Deinitable](var mapped:C,trace:ArcPointer[String]):
    comptime if mutable:exercise_mut(mapped^,trace)
    else:exercise_once(mapped^,trace)


def check[which:Int,mutable:Bool](fail:Bool) raises:
    var trace=ArcPointer(String())
    comptime if mutable:
        mapped[which,True](Mutable(Owner(3,trace),fail,0),trace)
    else:
        mapped[which,False](Once(Owner(3,trace),fail),trace)
    comptime if mutable:
        var expected = "m112m2123" if not fail else "m121em221e3" if which==1 else "m112em212e3"
        assert_equal(trace[],expected)
    else:
        var expected = "c312" if not fail else "c321e" if which==1 else "c312e"
        assert_equal(trace[],expected)


def mapped[which:Int,mutable:Bool,F:UnaryContract & Movable & Deinitable](var function:F,trace:ArcPointer[String]):
    comptime if which==0:
        exercise[mutable](_MapFirst[F,Owner](function^),trace)
    elif which==1:
        exercise[mutable](_MapValue[Owner,F](function^),trace)
    else:
        exercise[mutable](_Censor[F,Owner](function^),trace)

def main() raises:
    for fail in [False,True]:
        check[0,False](fail)
        check[1,False](fail)
        check[2,False](fail)
        check[0,True](fail)
        check[1,True](fail)
        check[2,True](fail)
