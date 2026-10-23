"""Conditional recovery moves errors and cleans up both callbacks on every path."""
from fp.algebra import ResultFamily, ListFamily, fail
from fp.effects import ReaderT, ResultT, run
from fp.functions import piped
from fp.callables import OnceUnary, MutableUnary, BorrowOnceCallable, BorrowCallable
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct CEOOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct CEOPredicate(BorrowOnceCallable):
    var capture: CEOOwner
    var selected: Bool
    var throws: Bool
    comptime Payload = CEOOwner
    comptime Result = Bool
    comptime Failure = Int
    def invoke_once(deinit self, ref error: CEOOwner) raises Int capturing -> Bool:
        if self.throws: raise 71
        return self.selected


@fieldwise_init
struct CEOHandler(OnceUnary):
    var capture: CEOOwner
    var calls: ArcPointer[Int]
    var throws: Bool
    comptime Arg = CEOOwner
    comptime Out = CEOOwner
    comptime Error = Int
    def call_once(deinit self, var error: CEOOwner) raises Int -> CEOOwner:
        self.calls[] += 1
        if self.throws: raise 72
        return error^


def ceo_path(ok: Bool, selected: Bool, throw_predicate: Bool, throw_handler: Bool) raises:
    comptime F = ResultFamily[CEOOwner]
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    var result: Result[CEOOwner, CEOOwner]
    if ok: result = Ok(CEOOwner(9, drops))
    else: result = Err(CEOOwner(4, drops))
    var code = 0
    var value = 0
    try:
        var recovered = piped(result^).recover_if[F](CEOPredicate(CEOOwner(1, drops), selected, throw_predicate), CEOHandler(CEOOwner(2, drops), calls, throw_handler)).get()
        if recovered.is_ok(): value = recovered._ok().value.value
        else: value = recovered._err().value.value
    except error:
        code = error
    assert_equal(drops[], 3)
    assert_equal(calls[], Int(not ok and selected and not throw_predicate))
    assert_equal(code, 0 if ok else 71 if throw_predicate else 72 if selected and throw_handler else 0)
    if code == 0: assert_equal(value, 9 if ok else 4)


@fieldwise_init
struct CEORepeatedPredicate(BorrowCallable):
    var capture: CEOOwner
    comptime Payload = CEOOwner
    comptime Result = Bool
    def invoke(self, ref error: CEOOwner) raises Never capturing -> Bool:
        return error.value > 0


@fieldwise_init
struct CEORepeatedHandler(MutableUnary):
    var capture: CEOOwner
    comptime Arg = CEOOwner
    comptime Out = Int
    comptime Error = Int
    def call_mut(mut self, var error: CEOOwner) raises Int -> Int: raise 73


def ceo_branching() raises:
    comptime L = ResultT[ListFamily, CEOOwner]
    var drops = ArcPointer(0)
    var items: List[Result[Int, CEOOwner]] = [Result[Int, CEOOwner](Err(CEOOwner(1, drops))), Result[Int, CEOOwner](Err(CEOOwner(2, drops)))]
    var code = 0
    try:
        _ = piped(items^).recover_if[L](CEORepeatedPredicate(CEOOwner(0, drops)), CEORepeatedHandler(CEOOwner(0, drops))).get()
    except error:
        code = error
    assert_equal(code, 73)
    assert_equal(drops[], 4)


def ceo_pending(drops: ArcPointer[Int], calls: ArcPointer[Int], execute: Bool):
    comptime R = ReaderT[ResultFamily[CEOOwner], Int]
    var pending = piped(fail[R, CEOOwner](CEOOwner(4, drops))).recover_if[R](CEOPredicate(CEOOwner(1, drops), True, False), CEOHandler(CEOOwner(2, drops), calls, False)).get()
    if execute:
        try:
            _ = run[R](pending^, 0)
        except error:
            calls[] = -100


def main() raises:
    ceo_path(True, True, True, True)
    ceo_path(False, False, False, True)
    ceo_path(False, True, False, False)
    ceo_path(False, True, True, False)
    ceo_path(False, True, False, True)
    ceo_branching()
    var drops = ArcPointer(0)
    var calls = ArcPointer(0)
    ceo_pending(drops, calls, False)
    assert_equal(drops[], 3)
    assert_equal(calls[], 0)
    ceo_pending(drops, calls, True)
    assert_equal(drops[], 6)
    assert_equal(calls[], 1)
    print("conditional error ownership: ok")
