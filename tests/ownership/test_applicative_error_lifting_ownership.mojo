"""Saved state, selected errors and deferred captures retain their owners."""
from fp.algebra import ResultFamily, fail, ApplicativeError
from fp.effects import StateT, ReaderT, ResultT, State, action, run
from fp.functions import pipeline
from fp.callables import OnceUnary
from fp.data import Result, Ok, Err
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct AELTrackedState(Copyable, Movable):
    var value: Int
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct AELTrackedError(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


comptime AELOBase = ResultFamily[AELTrackedError]
comptime AELOState = StateT[AELOBase, AELTrackedState]


@fieldwise_init
struct AELOSource(OnceUnary):
    var error: AELTrackedError
    var native: Bool
    comptime Arg = AELTrackedState
    comptime Out = Result[Tuple[Int, AELTrackedState], AELTrackedError]
    comptime Error = Int
    def call_once(deinit self, var state: Self.Arg) raises Int -> Self.Out:
        state.value += 100
        if self.native: raise state.value
        return Err(self.error^)


@fieldwise_init
struct AELOHandler(OnceUnary):
    var capture: AELTrackedError
    var native: Bool
    comptime Arg = AELTrackedError
    comptime Out = Int
    comptime Error = Int
    def call_once(deinit self, var error: Self.Arg) raises Int -> Int:
        if self.native: raise 91
        return self.capture.value + error.value


def aelo_state_case(copies: ArcPointer[Int], states: ArcPointer[Int], errors: ArcPointer[Int], source_native: Bool, handler_native: Bool) raises:
    var source = action[AELOState, Int](AELOSource(AELTrackedError(2, errors), source_native))
    var pending = pipeline[AELOState](source^).recover(AELOHandler(AELTrackedError(3, errors), handler_native)).get()
    assert_equal(copies[], 0)
    var result: Result[Tuple[Int, AELTrackedState], AELTrackedError]
    try:
        result = run[AELOState](pending^, AELTrackedState(5, copies, states))
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 105 if source_native else 91)
        return
    assert_equal(source_native or handler_native, False)
    assert_equal(copies[], 1)
    assert_equal(states[], 1)
    assert_equal(result._ok().value[0], 5)
    assert_equal(result._ok().value[1].value, 5)


def aelo_abandoned(errors: ArcPointer[Int]) raises:
    comptime R = ReaderT[AELOBase, Int]
    var pending = pipeline[R](fail[R, Int](AELTrackedError(2, errors))).recover(AELOHandler(AELTrackedError(3, errors), False)).get()
    assert_equal(errors[], 0)
    # Drop without run: neither the error nor the consuming handler is invoked.
    _ = pending^


def aelo_reader(errors: ArcPointer[Int]) raises:
    comptime R = ReaderT[AELOBase, Int]
    var pending = pipeline[R](fail[R, Int](AELTrackedError(2, errors))).recover(AELOHandler(AELTrackedError(3, errors), False)).get()
    var environment = 7
    var result: Result[Int, AELTrackedError]
    try:
        result = run[R](pending^, environment)
    except error:
        raise Error("unexpected native error")
    assert_equal(errors[], 2)
    assert_equal(result._ok().value, 5)


@fieldwise_init
struct AELOMoveState(Movable):
    var value: Int


def aelo_move_state() raises:
    comptime assert not conforms_to(StateT[AELOBase, AELOMoveState], ApplicativeError)
    comptime M = ResultT[State[AELOMoveState], Int]
    comptime assert conforms_to(M, ApplicativeError)
    def restore(var error: Int) -> Int: return error + 1
    var pending = pipeline[M](fail[M, Int](4)).recover(restore).get()
    var result = run[State[AELOMoveState]](pending^, AELOMoveState(9))
    assert_equal(result[0]._ok().value, 5)
    assert_equal(result[1].value, 9)


def main() raises:
    for mode in range(3):
        var copies = ArcPointer(0)
        var states = ArcPointer(0)
        var errors = ArcPointer(0)
        aelo_state_case(copies, states, errors, mode == 1, mode == 2)
        assert_equal(copies[], 1)
        assert_equal(states[], 2)
        assert_equal(errors[], 2)
    var errors = ArcPointer(0)
    aelo_abandoned(errors)
    assert_equal(errors[], 2)
    errors[] = 0
    aelo_reader(errors)
    assert_equal(errors[], 2)
    aelo_move_state()
    print("applicative error lifting ownership: ok")
