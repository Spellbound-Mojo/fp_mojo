"""State and log rebinding moves owners without rollback or extra copies."""
from fp.algebra import ApplicativeError, ErrorMapping, ResultFamily, Monoid
from fp.callables import OnceUnary
from fp.effects import ReaderT, StateT, WriterT, action, writer, run, run_writer
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Owner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Step(OnceUnary):
    var token: Owner
    var calls: ArcPointer[Int]
    var observed: ArcPointer[Int]
    var mode: Int
    comptime Arg = Owner
    comptime Out = Result[Tuple[Int,Owner],String]
    comptime Error = Int
    def call_once(deinit self, var state: Owner) raises Int -> Self.Out:
        self.calls[] += 1
        state.value += 10
        self.observed[] = state.value
        if self.mode == 1: return Err(String("old"))
        if self.mode == 2: raise 784
        return Ok(Tuple(state.value,state^))

@fieldwise_init
struct ChangeError(OnceUnary):
    var token: Owner
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Arg = String
    comptime Out = Int
    comptime Error = Int
    def call_once(deinit self, var error: String) raises Int -> Int:
        self.calls[] += 1
        if self.fail: raise 785
        return error.byte_length()

def state_case(source_drops: ArcPointer[Int], mapper_drops: ArcPointer[Int], state_drops: ArcPointer[Int], source_calls: ArcPointer[Int], mapper_calls: ArcPointer[Int], observed: ArcPointer[Int], mode: Int, fail: Bool, execute: Bool) -> Int:
    comptime S = StateT[ResultFamily[String],Owner]
    comptime S2 = StateT[ResultFamily[Int],Owner]
    comptime assert conforms_to(S,ErrorMapping)
    comptime assert not conforms_to(S,ApplicativeError)
    comptime assert not conforms_to(Owner,Copyable)
    var source = action[S,Int](Step(Owner(1,source_drops),source_calls,observed,mode))
    var pending = pipeline[S](source^).map_err(ChangeError(Owner(2,mapper_drops),mapper_calls,fail)).get()
    comptime assert not conforms_to(type_of(pending),Copyable)
    if not execute: return 0
    try:
        var result = run[S2](pending^,Owner(11,state_drops))
        if result.is_err(): return result._err().value
        return result._ok().value[0] + result._ok().value[1].value
    except error:
        comptime assert type_of(error) == Int
        return error

struct OwnedLog(Monoid):
    comptime Value = Owner
    @staticmethod
    def empty() -> Owner: return Owner(0,ArcPointer(0))
    @staticmethod
    def combine(var left: Owner, var right: Owner) -> Owner:
        left.value += right.value
        return left^

@fieldwise_init
struct ChangeValue(OnceUnary):
    var token: Owner
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Arg = Int
    comptime Out = String
    comptime Error = Int
    def call_once(deinit self, var value: Int) raises Int -> String:
        self.calls[] += 1
        if self.fail: raise 786
        return String(value)

def writer_case(log_drops: ArcPointer[Int], capture_drops: ArcPointer[Int], calls: ArcPointer[Int], mode: Int) -> Int:
    comptime R = ReaderT[ResultFamily[String],Int]
    comptime R2 = ReaderT[ResultFamily[Int],Int]
    comptime W = WriterT[R,OwnedLog]
    comptime W2 = WriterT[R2,OwnedLog]
    var source = writer[W,Int](R.pure(Tuple(Owner(9,log_drops),5)))
    def size(var error: String) -> Int: return error.byte_length()
    var pending = pipeline[W](source^).map_both(ChangeValue(Owner(1,capture_drops),calls,mode==1),size)
    comptime assert type_of(pending).I == W2
    comptime assert not conforms_to(type_of(pending),Copyable)
    if mode == 2: return 0
    try:
        var result = run[R2](run_writer[W2](pending^.get()),0)
        return result._ok().value[0].value + result._ok().value[1].byte_length()
    except error:
        comptime assert type_of(error) == Int
        return error

def main() raises:
    for execute in range(2):
        for mode in range(3):
            for fails in range(2):
                var source_drops = ArcPointer(0)
                var mapper_drops = ArcPointer(0)
                var state_drops = ArcPointer(0)
                var source_calls = ArcPointer(0)
                var mapper_calls = ArcPointer(0)
                var observed = ArcPointer(0)
                var value = state_case(source_drops,mapper_drops,state_drops,source_calls,mapper_calls,observed,mode,Bool(fails),Bool(execute))
                assert_equal(value,0 if execute==0 else 42 if mode==0 else 784 if mode==2 else 785 if fails else 3)
                assert_equal(source_drops[],1)
                assert_equal(mapper_drops[],1)
                assert_equal(state_drops[],execute)
                assert_equal(source_calls[],execute)
                assert_equal(mapper_calls[],1 if execute and mode==1 else 0)
                assert_equal(observed[],21 if execute else 0)
    for mode in range(3):
        var logs = ArcPointer(0)
        var captures = ArcPointer(0)
        var calls = ArcPointer(0)
        assert_equal(writer_case(logs,captures,calls,mode),10 if mode==0 else 786 if mode==1 else 0)
        assert_equal(logs[],1)
        assert_equal(captures[],1)
        assert_equal(calls[],0 if mode==2 else 1)
