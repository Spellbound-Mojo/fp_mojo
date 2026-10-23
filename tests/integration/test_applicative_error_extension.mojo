"""A third-party capability implementation uses only public contracts."""
from fp.algebra import ApplicativeError, ResultFamily, fail
from fp.callables import UnaryContract, BinaryContract, ThunkContract
from fp.functions import piped
from fp.data import Result, Ok, Err
from std.testing import assert_equal


@fieldwise_init
struct AEXConstructionError(Movable):
    var value: Int


struct AEXFamily(ApplicativeError):
    # This family reuses Result execution and adds a fallible constructor.
    comptime Failure = String
    comptime Element[V: Movable & Deinitable] = ResultFamily[String].Element[V]
    comptime Pure[A: Movable & Deinitable] = Result[A, String]
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = ResultFamily[String].Mapped[V, F]
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = F.Error
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = ResultFamily[String].Combined[V, F, G]
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, G: ThunkContract & Movable & Deinitable] = ResultFamily[String].CombineError[V, F, G]
    comptime Failed[A: Movable & Deinitable] = Self.Pure[A]
    comptime FailError[A: Movable & Deinitable] = AEXConstructionError
    comptime Handled[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = ResultFamily[String].Handled[V, H]
    comptime HandleError[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable] = H.Error

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
        if error == "construct": raise AEXConstructionError(31)
        return ResultFamily[String].fail[A](error^)

    @staticmethod
    def or_else[V: Movable & Deinitable, H: UnaryContract & Movable & Deinitable](var handler: H, var source: V) raises Self.HandleError[V, H] -> Self.Handled[V, H]:
        return ResultFamily[String].or_else(handler^, source^)


def main() raises:
    def restore(var error: String) -> Int: return error.byte_length()
    var stored: Result[Int, String]
    try:
        stored = fail[AEXFamily, Int](String("missing"))
    except error:
        raise Error("unexpected construction failure")
    assert_equal(piped(stored^).recover[AEXFamily](restore).get()._ok().value, 7)
    var code = 0
    try:
        _ = fail[AEXFamily, Int](String("construct"))
    except error:
        comptime assert type_of(error) == AEXConstructionError
        code = error.value
    assert_equal(code, 31)
    def aex_matches(error: String) -> Bool: return error == "construct"
    def aex_never(error: String) -> Bool: return False
    # Matching recovery never reconstructs the old failure. A non-match uses
    # the family's constructor and must propagate its exact native error.
    var match_code: Int
    try:
        var recovered = piped(Result[Int, String](Err(String("construct")))).recover_if[AEXFamily](aex_matches, restore).get()
        match_code = recovered._ok().value
    except error:
        match_code = -1
    assert_equal(match_code, 9)
    code = 0
    try:
        _ = piped(Result[Int, String](Err(String("construct")))).recover_if[AEXFamily](aex_never, restore).get()
    except error:
        comptime assert type_of(error) == AEXConstructionError
        code = error.value
    assert_equal(code, 31)
    print("applicative error extension: ok")
