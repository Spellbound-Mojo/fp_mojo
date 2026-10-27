"""Transport rebinding preserves selected contexts, execution timing and policy."""
from fp.algebra import ApplicativeError, ErrorMapping, ResultFamily, StringMonoid, ValidationFamily, Monad
from fp.callables import Unary
from fp.data import Result, Ok, Err
from fp.effects import ReaderT, StateT, WriterT, run, run_writer, writer
from fp.functions import pipeline
from std.testing import assert_equal
from context_layer_error_mapping_support import MappingMonad
from context_error_mapping_nonmonad_support import ToValidation

@fieldwise_init
struct Show(Unary):
    comptime Arg = Int
    comptime Out = String
    def call(self, var value: Int) -> String: return String(value)

def ordinary() raises:
    comptime M = ResultFamily[String]
    comptime N = ResultFamily[Int]
    comptime R = ReaderT[M,Int]
    comptime R2 = ReaderT[N,Int]
    comptime S = StateT[M,Int]
    comptime S2 = StateT[N,Int]
    comptime W = WriterT[M,StringMonoid]
    comptime W2 = WriterT[N,StringMonoid]
    var calls = 0
    def size(var error: String) {mut calls} -> Int:
        calls += 1
        return error.byte_length()
    def length(var value: String) -> Int: return value.byte_length()
    var reader = pipeline[R](R.fail[Int](String("reader"))).map_err(size)
    comptime assert type_of(reader).I == R2
    assert_equal(calls,0)
    assert_equal(run[R2](reader^.get(),8)._err().value,6)
    assert_equal(calls,1)
    var changed = pipeline[R](R.pure(12)).map_both(Show(),size)
    comptime assert type_of(changed).I == R2
    assert_equal(run[R2](changed^.map(length).get(),8)._ok().value,2)
    assert_equal(calls,1)
    var state = pipeline[S](S.pure(13)).map_both(Show(),size)
    comptime assert type_of(state).I == S2
    var state_result = run[S2](state^.map(length).get(),37)
    assert_equal(state_result._ok().value[0],2)
    assert_equal(state_result._ok().value[1],37)
    assert_equal(run[S2](pipeline[S](S.fail[Int](String("state"))).map_err(size).get(),37)._err().value,5)
    var logged = writer[W,Int](M.pure(Tuple(String("log"),14)))
    var written = pipeline[W](logged^).map_both(Show(),size)
    comptime assert type_of(written).I == W2
    var write_result = run_writer[W2](written^.map(length).get())
    assert_equal(write_result._ok().value[0],"log")
    assert_equal(write_result._ok().value[1],2)
    assert_equal(run_writer[W2](pipeline[W](W.fail[Int](String("writer"))).map_err(size).get())._err().value,6)
    assert_equal(calls,3)
    # Stored native pointers are owned by a deferred operation.
    def first(var error: String) -> Int: return error.byte_length()
    def replacement(var error: String) -> Int: return 99
    var pointer: def(var String) thin -> Int = first
    var stored = pipeline[R](R.fail[Int](String("four"))).map_err(pointer).get()
    pointer = replacement
    assert_equal(pointer(String("x")),99)
    assert_equal(run[R2](stored^,0)._err().value,4)

def native_errors() raises:
    comptime R = ReaderT[ResultFamily[String],Int]
    comptime R2 = ReaderT[ResultFamily[Int],Int]
    def raising(var error: String) raises Int -> Int: raise 782
    var pending = pipeline[R](R.fail[Int](String("stored"))).raising[Int]().map_err(raising).get()
    var code = 0
    try: _ = run[R2](pending^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,782)
    # A success callback may raise while the error arm is an ordinary native function.
    def reject(var value: Int) raises Int -> String: raise value
    def size(var error: String) -> Int: return error.byte_length()
    var both = pipeline[R](R.pure(783)).raising[Int]().map_both(reject,size).get()
    try: _ = run[R2](both^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,783)

def mapping_only() raises:
    comptime M = MappingMonad[String]
    comptime N = MappingMonad[Int]
    comptime assert not conforms_to(M,ApplicativeError)
    comptime R = ReaderT[M,Int]
    comptime S = StateT[M,Int]
    comptime W = WriterT[M,StringMonoid]
    comptime assert conforms_to(R,ErrorMapping) and not conforms_to(R,ApplicativeError)
    comptime assert conforms_to(S,ErrorMapping) and not conforms_to(S,ApplicativeError)
    comptime assert conforms_to(W,ErrorMapping) and not conforms_to(W,ApplicativeError)
    def size(var error: String) -> Int: return error.byte_length()
    assert_equal(run[ReaderT[N,Int]](pipeline[R](R.lift(Result[Int,String](Err(String("reader"))))).map_err(size).get(),0)._err().value,6)
    assert_equal(run[StateT[N,Int]](pipeline[S](S.lift(Result[Int,String](Err(String("state"))))).map_err(size).get(),0)._err().value,5)
    var stored = writer[W,Int](Result[Tuple[String,Int],String](Err(String("writer"))))
    assert_equal(run_writer[WriterT[N,StringMonoid]](pipeline[W](stored^).map_err(size).get())._err().value,6)

def family_errors() raises:
    comptime M = MappingMonad[String,True]
    comptime N = MappingMonad[Int,True]
    comptime R = ReaderT[M,Int]
    comptime S = StateT[M,Int]
    comptime W = WriterT[M,StringMonoid]
    var calls = 0
    def size(var error: String) {mut calls} -> Int:
        calls += 1
        return error.byte_length()
    var reader = pipeline[R](R.pure(1)).map_err(size).get()
    var state = pipeline[S](S.pure(2)).map_err(size).get()
    assert_equal(calls,0)
    var code = 0
    try: _ = run[ReaderT[N,Int]](reader^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,781)
    try: _ = run[StateT[N,Int]](state^,0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,781)
    try: _ = pipeline[W](W.pure(3)).map_err(size).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code,781)
    assert_equal(calls,0)


def default_policy() raises:
    # A legitimate base destination need not support a transformer's Monad base.
    comptime M = ToValidation
    comptime N = ResultFamily[String]
    comptime assert conforms_to(M,Monad) and conforms_to(M,ErrorMapping)
    comptime assert not conforms_to(M.DefaultErrorTarget[Int,String],Monad)
    def tag(var error: String) -> String: return "mapped:" + error
    var direct = pipeline[M](Result[Int,String](Err(String("base")))).map_err(tag)
    comptime assert type_of(direct).I == ValidationFamily[StringMonoid]
    assert_equal(direct^.get()._err().value,"mapped:base")
    # Explicit admitted Monad destinations remain independent of the default.
    comptime R = ReaderT[M,Int]
    comptime R2 = ReaderT[N,Int]
    var reader = pipeline[R](R.lift(Result[Int,String](Err(String("reader"))))).map_err[Target=R2](tag).get()
    assert_equal(run[R2](reader^,0)._err().value,"mapped:reader")
    comptime S = StateT[M,Int]
    comptime S2 = StateT[N,Int]
    var state = pipeline[S](S.lift(Result[Int,String](Err(String("state"))))).map_err[Target=S2](tag).get()
    assert_equal(run[S2](state^,0)._err().value,"mapped:state")
    comptime W = WriterT[M,StringMonoid]
    comptime W2 = WriterT[N,StringMonoid]
    var stored = writer[W,Int](Result[Tuple[String,Int],String](Err(String("writer"))))
    var logged = pipeline[W](stored^).map_err[Target=W2](tag).get()
    assert_equal(run_writer[W2](logged^)._err().value,"mapped:writer")

def main() raises:
    ordinary()
    native_errors()
    mapping_only()
    family_errors()
    default_policy()
