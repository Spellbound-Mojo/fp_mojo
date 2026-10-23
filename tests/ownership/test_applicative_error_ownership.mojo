"""Shared recovery moves owners once and destroys skipped and unvisited captures."""
from fp.algebra import ResultFamily, ListFamily, fail
from fp.effects import ResultT, State, Reader, action, run
from fp.functions import piped
from fp.callables import OnceUnary, MutableUnary
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct AEOOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct AEORestore(OnceUnary):
    var captured: AEOOwner
    var throws: Bool
    comptime Arg = AEOOwner
    comptime Out = AEOOwner
    comptime Error = Int
    def call_once(deinit self, var error: AEOOwner) raises Int -> AEOOwner:
        if self.throws: raise 90
        self.captured.value += error.value
        return self.captured^


@fieldwise_init
struct AEORepeat(MutableUnary):
    var captured: AEOOwner
    comptime Arg = AEOOwner
    comptime Out = Int
    comptime Error = Int
    def call_mut(mut self, var error: AEOOwner) raises Int -> Int:
        raise error.value


@fieldwise_init
struct AEOStateStep(OnceUnary):
    comptime Arg = AEOOwner
    comptime Out = Tuple[Result[Int, Int], AEOOwner]
    def call_once(deinit self, var state: AEOOwner) -> Self.Out:
        state.value += 10
        return (Result[Int, Int](Err(4)), state^)


def aeo_paths() raises:
    comptime F = ResultFamily[AEOOwner]
    var drops = ArcPointer(0)
    with_scope_success(drops)
    assert_equal(drops[], 2)
    drops[] = 0
    with_scope_failure(drops)
    assert_equal(drops[], 2)
    drops[] = 0
    var code = 0
    try:
        _ = piped(fail[F, AEOOwner](AEOOwner(1, drops))).recover[F](AEORestore(AEOOwner(8, drops), True)).get()
    except error:
        code = error
    assert_equal(code, 90)
    assert_equal(drops[], 2)
    drops[] = 0
    comptime L = ResultT[ListFamily, AEOOwner]
    var items: List[Result[Int, AEOOwner]] = [Result[Int, AEOOwner](Err(AEOOwner(1, drops))), Result[Int, AEOOwner](Err(AEOOwner(2, drops)))]
    code = 0
    try:
        _ = piped(items^).recover[L](AEORepeat(AEOOwner(8, drops))).get()
    except error:
        code = error
    assert_equal(code, 1)
    assert_equal(drops[], 3)


def with_scope_success(drops: ArcPointer[Int]) raises:
    comptime F = ResultFamily[AEOOwner]
    var result = piped(Result[AEOOwner, AEOOwner](Ok(AEOOwner(4, drops)))).recover[F](AEORestore(AEOOwner(8, drops), True)).get()
    assert_equal(drops[], 1)
    assert_equal(result._ok().value.value, 4)


def with_scope_failure(drops: ArcPointer[Int]) raises:
    comptime F = ResultFamily[AEOOwner]
    var result = piped(fail[F, AEOOwner](AEOOwner(4, drops))).recover[F](AEORestore(AEOOwner(8, drops), False)).get()
    assert_equal(drops[], 1)
    assert_equal(result._ok().value.value, 12)


def aeo_deferred(drops: ArcPointer[Int]) raises:
    comptime S = State[AEOOwner]
    comptime T = ResultT[S, Int]
    def restore(var error: Int) -> Int: return error + 1
    var state = piped(action[S, Result[Int, Int]](AEOStateStep())).recover[T](restore).get()
    var result = run[S](state^, AEOOwner(5, drops))
    assert_equal(result[0]._ok().value, 5)
    assert_equal(drops[], 0)
    assert_equal(result[1].value, 15)


def aeo_pending(drops: ArcPointer[Int]) raises:
    comptime R = Reader[Int]
    comptime T = ResultT[R, AEOOwner]
    var pending = piped(fail[T, AEOOwner](AEOOwner(4, drops))).recover[T](AEORestore(AEOOwner(8, drops), False)).get()
    assert_equal(drops[], 0)
    var environment = 0
    var result = run[R](pending^, environment)
    assert_equal(drops[], 1)
    assert_equal(result._ok().value.value, 12)


def main() raises:
    aeo_paths()
    var drops = ArcPointer(0)
    aeo_deferred(drops)
    assert_equal(drops[], 1)
    drops[] = 0
    aeo_pending(drops)
    assert_equal(drops[], 2)
    print("applicative error ownership: ok")
