"""Lifted failure constructors preserve native construction errors and timing."""
from fp.algebra import ApplicativeError, Monad, Monoid, ResultFamily, fail
from fp.callables import UnaryContract, BinaryContract, ThunkContract
from fp.effects import ReaderT, StateT, WriterT, OptionalT, run, run_writer
from fp.data import Result, Ok
from fp.functions import piped
from std.testing import assert_equal


@fieldwise_init
struct AELConstructionFailure(Movable):
    var value: Int


struct AELConstructorBase(Monad, ApplicativeError):
    # This family reuses Result execution and adds a fallible constructor.
    comptime Failure = String
    comptime Element[V: Movable & Deinitable] = ResultFamily[String].Element[V]
    comptime Pure[A: Movable & Deinitable] = Result[A, String]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ResultFamily[String].Mapped[V, F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = ResultFamily[String].Combined[V, F, G]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = ResultFamily[String].CombineError[V, F, G]
    comptime Failed[A: Movable & Deinitable] = Self.Pure[A]
    comptime FailError[A: Movable & Deinitable] = AELConstructionFailure
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = ResultFamily[String].Handled[V, H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = H.Error

    comptime Bound[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Out
    comptime BindError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error

    @staticmethod
    def flat_map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.BindError[V, F] -> Self.Bound[V, F]:
        return ResultFamily[String].flat_map(f^, value^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> Self.Pure[A]:
        return ResultFamily[String].pure(value^)

    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) raises Self.MapError[V, F] -> Self.Mapped[V, F]:
        return ResultFamily[String].map(f^, value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: G) raises Self.CombineError[V, F, G] -> Self.Combined[V, F, G]:
        return ResultFamily[String].map2_lazy(f^, left^, right^)

    @staticmethod
    def fail[A: Movable & Deinitable](var error: String) raises Self.FailError[A] -> Self.Failed[A]:
        if error == "construct": raise AELConstructionFailure(31)
        return ResultFamily[String].fail[A](error^)

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.HandleError[V, H] -> Self.Handled[V, H]:
        return ResultFamily[String].or_else(handler^, source^)



struct AELRaisingLog(Monoid):
    comptime Value = String
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> String: raise 99
    @staticmethod
    def combine(var left: String, var right: String) raises Int -> String: raise 98


def main() raises:
    comptime R = ReaderT[AELConstructorBase, Int]
    comptime S = StateT[AELConstructorBase, Int]
    # These constructors are non-raising; the base factory runs only at run.
    var reader = fail[R, Int](String("construct"))
    var state = fail[S, Int](String("construct"))
    def fallback(var error: String) -> Int: return 9
    var protected_read = piped(reader^).recover[R](fallback).get()
    var protected_state = piped(state^).recover[S](fallback).get()
    var code = 0
    try:
        _ = run[R](protected_read^, 0)
    except error:
        comptime assert type_of(error) == AELConstructionFailure
        code = error.value
    assert_equal(code, 31)
    code = 0
    try:
        _ = run[S](protected_state^, 0)
    except error:
        comptime assert type_of(error) == AELConstructionFailure
        code = error.value
    assert_equal(code, 31)
    comptime W = WriterT[AELConstructorBase, AELRaisingLog]
    code = 0
    try:
        _ = fail[W, Int](String("construct"))
    except error:
        comptime assert type_of(error) == AELConstructionFailure
        code = error.value
    assert_equal(code, 31)
    comptime O = OptionalT[AELConstructorBase]
    code = 0
    try:
        _ = fail[O, Int](String("construct"))
    except error:
        comptime assert type_of(error) == AELConstructionFailure
        code = error.value
    assert_equal(code, 31)
    # No log exists in a failed base; failure construction must not call empty.
    comptime PlainWriter = WriterT[ResultFamily[String], AELRaisingLog]
    var failed = fail[PlainWriter, Int](String("stored"))
    assert_equal(run_writer[PlainWriter](failed^)._err().value, "stored")
    print("applicative error lifting construction: ok")
