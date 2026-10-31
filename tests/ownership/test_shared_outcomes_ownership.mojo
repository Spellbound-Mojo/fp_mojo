"""Shared outcome operations move captures and values, including skipped paths."""
from fp.algebra import ResultFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import pipeline
from fp.callables import BorrowOnceCallable, OnceUnary
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct SOOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct SOPredicate(BorrowOnceCallable):
    var token: SOOwner
    var accept: Bool
    var throws: Bool
    comptime Payload = SOOwner
    comptime Result = Bool
    comptime Failure = Int
    def invoke_once(deinit self, ref value: SOOwner) raises Int capturing -> Bool:
        if self.throws: raise 71
        return self.accept

@fieldwise_init
struct SOFactory(BorrowOnceCallable):
    var token: SOOwner
    var throws: Bool
    comptime Payload = SOOwner
    comptime Result = SOOwner
    comptime Failure = Int
    def invoke_once(deinit self, ref value: SOOwner) raises Int capturing -> SOOwner:
        if self.throws: raise 72
        return self.token^

@fieldwise_init
struct SOHandler(OnceUnary):
    var token: SOOwner
    var throws: Bool
    comptime Arg = SOOwner
    comptime Out = SOOwner
    comptime Error = Int
    def call_once(deinit self, var value: SOOwner) raises Int -> SOOwner:
        if self.throws: raise 73
        return self.token^

@fieldwise_init
struct SOEffectHandler(OnceUnary):
    var token: SOOwner
    var failed: Bool
    comptime Arg = SOOwner
    comptime Out = Result[SOOwner, SOOwner]
    def call_once(deinit self, var value: SOOwner) -> Self.Out:
        if self.failed: return Err(self.token^)
        return Ok(self.token^)

@fieldwise_init
struct SOObserver(BorrowOnceCallable):
    var token: SOOwner
    var failed: Bool
    var throws: Bool
    comptime Payload = Result[SOOwner, SOOwner]
    comptime Result = Result[SOOwner, SOOwner]
    comptime Failure = Int
    def invoke_once(deinit self, ref outcome: Self.Payload) raises Int capturing -> Self.Result:
        if self.throws: raise 74
        if self.failed: return Err(self.token^)
        return Ok(self.token^)

def soo_ensure(drops: ArcPointer[Int], branch: Int) -> Int:
    comptime F = ResultFamily[SOOwner]
    comptime R = Result[SOOwner, SOOwner]
    var source = R(Err(SOOwner(1, drops))) if branch == 2 else R(Ok(SOOwner(1, drops)))
    try:
        var result = pipeline[F](source^).ensure(SOPredicate(SOOwner(2, drops), branch == 0, branch == 3), SOFactory(SOOwner(3, drops), branch == 4)).get()
        if result.is_ok(): return result._ok().value.value
        return result._err().value.value
    except error: return error

def soo_redeem(drops: ArcPointer[Int], failed: Bool, throws: Bool) -> Int:
    comptime F = ResultFamily[SOOwner]
    comptime R = Result[SOOwner, SOOwner]
    var source = R(Err(SOOwner(1, drops))) if failed else R(Ok(SOOwner(1, drops)))
    try:
        var result = pipeline[F](source^).redeem(SOHandler(SOOwner(2, drops), throws), SOHandler(SOOwner(3, drops), throws)).get()
        return result._ok().value.value
    except error: return error

def soo_with(drops: ArcPointer[Int], failed: Bool) -> Int:
    comptime F = ResultFamily[SOOwner]
    comptime R = Result[SOOwner, SOOwner]
    var source = R(Err(SOOwner(1, drops))) if failed else R(Ok(SOOwner(1, drops)))
    var result = pipeline[F](source^).redeem_with(SOEffectHandler(SOOwner(2, drops), True), SOEffectHandler(SOOwner(3, drops), False)).get()
    if result.is_ok(): return result._ok().value.value
    return result._err().value.value

def soo_tap(drops: ArcPointer[Int], failed: Bool, mode: Int) -> Int:
    comptime F = ResultFamily[SOOwner]
    comptime R = Result[SOOwner, SOOwner]
    var source = R(Err(SOOwner(1, drops))) if failed else R(Ok(SOOwner(1, drops)))
    try:
        var result = pipeline[F](source^).attempt_tap(SOObserver(SOOwner(2, drops), mode == 1, mode == 2)).get()
        if result.is_ok(): return result._ok().value.value
        return result._err().value.value
    except error: return error

def soo_deferred(drops: ArcPointer[Int], execute: Bool):
    comptime D = ReaderT[ResultFamily[SOOwner], Int]
    var pending = pipeline[D](fail[D, SOOwner](SOOwner(1, drops))).redeem(SOHandler(SOOwner(2, drops), False), SOHandler(SOOwner(3, drops), False)).get()
    if execute:
        try: _ = run[D](pending^, 0)
        except error: pass

def soo_branch_payload(drops: ArcPointer[Int]) raises:
    comptime F = ResultT[ListFamily, String]
    def inspect(outcome: Result[Int, String]) {drops} -> List[Result[SOOwner, String]]:
        return [Result[SOOwner, String](Ok(SOOwner(1, drops))), Result[SOOwner, String](Ok(SOOwner(2, drops)))]
    var values: List[Result[Int, String]] = [Result[Int, String](Ok(7))]
    var retained = pipeline[F](values^).attempt_tap(inspect).get()
    assert_equal(len(retained), 2)
    assert_equal(retained[0]._ok().value, 7)
    assert_equal(retained[1]._ok().value, 7)
    assert_equal(drops[], 2)

def main() raises:
    soo_branch_payload(ArcPointer(0))
    for branch in range(5):
        var drops = ArcPointer(0)
        assert_equal(soo_ensure(drops, branch), 1 if branch == 0 or branch == 2 else 3 if branch == 1 else 71 if branch == 3 else 72)
        assert_equal(drops[], 3)
    for failed in range(2):
        for throws in range(2):
            var drops = ArcPointer(0)
            assert_equal(soo_redeem(drops, Bool(failed), Bool(throws)), 73 if throws else 3 if failed else 2)
            assert_equal(drops[], 3)
        var with_drops = ArcPointer(0)
        assert_equal(soo_with(with_drops, Bool(failed)), 3 if failed else 2)
        assert_equal(with_drops[], 3)
        for mode in range(3):
            var drops = ArcPointer(0)
            assert_equal(soo_tap(drops, Bool(failed), mode), 1 if mode == 0 else 2 if mode == 1 else 74)
            assert_equal(drops[], 2)
        var deferred_drops = ArcPointer(0)
        soo_deferred(deferred_drops, Bool(failed))
        assert_equal(deferred_drops[], 3)
    print("shared outcomes ownership: ok")
