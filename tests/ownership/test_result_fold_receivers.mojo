"""Result folds preserve move-only payloads, handler state and exact failures."""
from fp.callables import BorrowCallContract, UnaryContract, BorrowCallable, BorrowMutableCallable, Unary, MutableUnary, mut_ref, invoke_borrowed_once
from fp.data import Result, Ok, Err
from algebra_support.result_ownership import Token, Trace, trace
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Shared(BorrowCallable, Unary):
    comptime Payload = Token
    comptime Result = Token
    comptime Failure = Token
    comptime Arg = Token
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    var fail: Bool
    def invoke(self, ref value: Token) raises Token -> Token:
        self.capture.trace[].calls += 1
        if self.fail: raise Token(7, self.capture.trace)
        return Token(1, self.capture.trace)
    def call(self, var value: Token) raises Token -> Token:
        return self.invoke(value)

@fieldwise_init
struct Mutable(BorrowMutableCallable, MutableUnary):
    comptime Payload = Token
    comptime Result = Token
    comptime Failure = Token
    comptime Arg = Token
    comptime Out = Token
    comptime Error = Token
    var capture: Token
    var fail: Bool
    var calls: Int
    def invoke_mut(mut self, ref value: Token) raises Token -> Token:
        self.calls += 1
        self.capture.trace[].calls += 1
        if self.fail: raise Token(7, self.capture.trace)
        return Token(1, self.capture.trace)
    def call_mut(mut self, var value: Token) raises Token -> Token:
        return self.invoke_mut(value)

def owned[borrowed: Bool, C: BorrowCallContract & UnaryContract & Movable & Deinitable](var yes: C, var no: C, state: ArcPointer[Trace], ok: Bool, fail: Bool) raises where C.Payload == Token and C.Arg == Token:
    var subject = Result[Token, Token](Ok(Token(2, state))) if ok else Result[Token, Token](Err(Token(2, state)))
    var failed = False
    comptime if borrowed:
        try:
            _ = subject.fold_once(yes^, no^)
        except error:
            _ = error^
            failed = True
        assert_equal(state[].drops[2], 0)
        assert_equal(subject.is_ok(), ok)
        _ = subject^
    else:
        try:
            _ = subject^.fold_owned_once(yes^, no^)
        except error:
            _ = error^
            failed = True
    assert_equal(failed, fail)
    assert_equal(state[].calls, 1)
    assert_equal(state[].drops[2], 1)
    assert_equal(state[].drops[5], 1)
    assert_equal(state[].drops[6], 1)
    assert_equal(state[].drops[1], Int(not fail))
    assert_equal(state[].drops[7], Int(fail))

def retained[borrowed: Bool](ok: Bool, fail: Bool) raises:
    var state = trace()
    var yes = Mutable(Token(5, state), fail, 0)
    var no = Mutable(Token(6, state), fail, 0)
    var subject = Result[Token, Token](Ok(Token(2, state))) if ok else Result[Token, Token](Err(Token(2, state)))
    var outcome: Result[Token, Token]
    comptime if borrowed:
        try:
            outcome = Ok(subject.fold_once(mut_ref(yes), mut_ref(no)))
        except error:
            outcome = Err(error^)
        assert_equal(state[].drops[2], 0)
        assert_equal(subject.is_ok(), ok)
        _ = subject^
    else:
        try:
            outcome = Ok(subject^.fold_owned_once(mut_ref(yes), mut_ref(no)))
        except error:
            outcome = Err(error^)
    assert_equal(yes.calls, Int(ok))
    assert_equal(no.calls, Int(not ok))
    assert_equal(outcome.is_err(), fail)
    assert_equal(state[].calls, 1)
    assert_equal(state[].drops[2], 1)
    assert_equal(state[].drops[5], 0)
    assert_equal(state[].drops[6], 0)
    _ = yes^
    _ = no^
    assert_equal(state[].drops[5], 1)
    assert_equal(state[].drops[6], 1)
    _ = outcome^
    assert_equal(state[].drops[1], Int(not fail))
    assert_equal(state[].drops[7], Int(fail))

@fieldwise_init
struct External[o: ImmOrigin](BorrowMutableCallable, MutableUnary):
    comptime Payload = Int
    comptime Result = Span[Int, Self.o]
    comptime Failure = Span[Int, Self.o]
    comptime Arg = Int
    comptime Out = Span[Int, Self.o]
    comptime Error = Span[Int, Self.o]
    var values: Self.Out
    var capture: Token
    var fail: Bool
    def invoke_mut(mut self, ref value: Int) raises Self.Failure -> Self.Result:
        self.capture.trace[].calls += 1
        if self.fail: raise self.values
        return self.values
    def call_mut(mut self, var value: Int) raises Self.Error -> Self.Out:
        return self.invoke_mut(value)

def external[route: Int](owner: List[Int], state: ArcPointer[Trace], fail: Bool) -> Result[Span[Int, origin_of(owner)], Span[Int, origin_of(owner)]]:
    var yes = External(Span(owner), Token(5, state), fail)
    var no = External(Span(owner), Token(6, state), fail)
    try:
        comptime if route == 0:
            return Ok(Result[Int,Int](Ok(4)).fold_once(yes^, no^))
        elif route == 1:
            return Ok(Result[Int,Int](Ok(4)).fold_owned_once(yes^, no^))
        else:
            return Ok(invoke_borrowed_once[Span[Int,origin_of(owner)]](4, yes^))
    except error:
        return Err(error)

def main() raises:
    comptime for borrowed in range(2):
        for ok in [False, True]:
            for fail in [False, True]:
                var shared = trace()
                owned[Bool(borrowed)](Shared(Token(5, shared), fail), Shared(Token(6, shared), fail), shared, ok, fail)
                var exclusive = trace()
                owned[Bool(borrowed)](Mutable(Token(5, exclusive), fail, 0), Mutable(Token(6, exclusive), fail, 0), exclusive, ok, fail)
                retained[Bool(borrowed)](ok, fail)

    var owner: List[Int] = [7,11]
    comptime for route in range(3):
        for fail in [False, True]:
            var state = trace()
            var result = external[route](owner,state,fail)
            assert_equal(result.is_err(),fail)
            assert_equal(state[].calls,1)
            assert_equal(state[].drops[5],1)
            assert_equal(state[].drops[6],1)
            if fail:
                var view = result^.swap().get_or(Span(owner))
                assert_equal(Pointer(to=view[0]) == Pointer(to=owner[0]), True)
            else:
                var view = result^.get_or(Span(owner))
                assert_equal(Pointer(to=view[0]) == Pointer(to=owner[0]), True)
