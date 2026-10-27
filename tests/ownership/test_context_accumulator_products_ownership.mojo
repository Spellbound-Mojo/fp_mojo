# Accumulator product adapters preserve stopping, native errors, and destruction order.
from fp.algebra import Monoid
from fp.algebra.protocols import _Accumulate
from fp.effects.writer import _WriterAcc
from fp.effects.state import _FoldState
from fp.callables import call_once,call_repeated,RepeatableUnary
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Owner(Movable):
    var id:Int
    var stopped:Bool
    var trace:ArcPointer[String]
    def __deinit__(deinit self):self.trace[]+=String(self.id)

struct Log[fail:Bool](Monoid):
    comptime Value=Owner
    comptime Error=Int
    @staticmethod
    def empty() raises Int ->Owner:raise 51
    @staticmethod
    def combine(var left:Owner,var right:Owner) raises Int ->Owner:
        left.trace[]+="w"
        if Self.fail:raise 71
        return left^

struct Acc[fail:Bool](_Accumulate):
    comptime Acc=Owner
    comptime Item=Owner
    comptime Error=Int
    @staticmethod
    def start() raises Int ->Owner:raise 52
    @staticmethod
    def live(ref value:Owner)->Bool:
        value.trace[]+="l"
        return not value.stopped
    @staticmethod
    def combine(var left:Owner,var right:Owner) raises Int ->Owner:
        left.trace[]+="k"
        if Self.fail:raise 83
        return left^

struct ScalarAcc[fail:Bool](_Accumulate):
    comptime Acc=Int
    comptime Item=Owner
    comptime Error=Int
    @staticmethod
    def start() raises Int ->Int:return 10
    @staticmethod
    def live(ref value:Int)->Bool:return True
    @staticmethod
    def combine(var left:Int,var right:Owner) raises Int ->Int:
        right.trace[]+="s"
        if Self.fail:raise 97
        return left+right.id

def writer[log_failure:Bool,acc_failure:Bool](stopped:Bool) raises:
    var trace=ArcPointer(String())
    comptime K=_WriterAcc[Log[log_failure],Acc[acc_failure]]
    var code=0
    try:
        var result=K.combine(Tuple(Owner(1,False,trace),Owner(2,stopped,trace)),Tuple(Owner(3,False,trace),Owner(4,False,trace)))
        _=result^
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,0 if stopped else 71 if log_failure else 83 if acc_failure else 0)
    var expected="l3412" if stopped else "l3w142" if log_failure else "l3w4k21" if acc_failure else "l3w4k12"
    assert_equal(trace[],expected)

def state_once[failure:Bool]() raises:
    comptime assert not RepeatableUnary[_FoldState[Acc[failure],Owner]]
    var trace=ArcPointer(String())
    var code=0
    try:
        var result=call_once(_FoldState[Acc[failure],Owner](Owner(1,False,trace)),Tuple(Owner(2,False,trace),Owner(3,False,trace)))
        _=result^
    except error:
        comptime assert type_of(error)==Int
        code=error
    assert_equal(code,83 if failure else 0)
    assert_equal(trace[],"2k13")

def state_mut[failure:Bool]() raises:
    comptime assert RepeatableUnary[_FoldState[ScalarAcc[failure],Owner]]
    comptime assert not conforms_to(_FoldState[ScalarAcc[failure],Owner],Copyable)
    var trace=ArcPointer(String())
    var f=_FoldState[ScalarAcc[failure],Owner](10)
    var answers=List[Int]()
    var code=0
    for _ in range(2):
        try:
            var result=call_repeated(f,Tuple(Owner(2,False,trace),Owner(3,False,trace)))
            answers.append(result[0])
            _=result^
        except error:
            comptime assert type_of(error)==Int
            code=error
    _=f^
    assert_equal(code,97 if failure else 0)
    assert_equal(answers,List[Int]() if failure else List[Int]([12,12]))
    assert_equal(trace[],"s23s23")

def main() raises:
    for stopped in [False,True]:
        writer[False,False](stopped)
        writer[True,False](stopped)
        writer[False,True](stopped)
        writer[True,True](stopped)
    state_once[False]()
    state_once[True]()
    state_mut[False]()
    state_mut[True]()
