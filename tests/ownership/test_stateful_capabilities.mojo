"""Selected updates retain move-only ownership and exact borrowed origins."""
from fp.effects import Stateful, LiftStateful, State, StateT, ReaderT, ResultT, get, put, modify, run
from fp.callables import OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct SCMove(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct SCOwnedCapture(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct SCUpdateOnce(OnceUnary):
    var capture: SCOwnedCapture
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Arg = SCMove
    comptime Out = SCMove
    comptime Error = Int
    def call_once(deinit self, var state: SCMove) raises Int -> SCMove:
        self.calls[] += 1
        if self.fail: raise 71
        state.value += 3
        return state^


def sc_owned_case(calls: ArcPointer[Int], captures: ArcPointer[Int], states: ArcPointer[Int], mode: Int) raises:
    comptime S = State[SCMove]
    comptime R = ReaderT[S, Int]
    comptime T = ResultT[R, String]
    comptime C = LiftStateful[T, LiftStateful[R, S]]
    comptime assert not C.GetAvailable
    var pending = modify[C](SCUpdateOnce(SCOwnedCapture(captures), calls, mode == 1))
    comptime assert not conforms_to(type_of(pending), Copyable)
    assert_equal(calls[], 0)
    if mode == 2:
        _ = pending^
        return
    var base = run[R](pending^, 42)
    assert_equal(calls[], 0)
    var succeeded = False
    var code = 0
    try:
        var result = run[S](base^, SCMove(10, states))
        succeeded = result[0].is_ok() and result[1].value == 13
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(succeeded, mode == 0)
    assert_equal(code, 71 if mode == 1 else 0)


def sc_put_case(states: ArcPointer[Int], abandon: Bool) raises:
    comptime S = State[SCMove]
    comptime T = ResultT[S, String]
    comptime C = LiftStateful[T, S]
    var pending = put[C](SCMove(20, states))
    comptime assert not conforms_to(type_of(pending), Copyable)
    assert_equal(states[], 0)
    if abandon:
        _ = pending^
        return
    var result = run[S](pending^, SCMove(10, states))
    assert_equal(states[], 1)
    assert_equal(result[1].value, 20)


def sc_two_move_states(states: ArcPointer[Int]) raises:
    comptime S = State[SCMove]
    comptime Two = StateT[S, SCMove]
    comptime C = LiftStateful[Two, S]
    var base = run[Two](put[C](SCMove(30, states)), SCMove(100, states))
    var result = run[S](base^, SCMove(10, states))
    assert_equal(states[], 1)
    assert_equal(result[0][1].value, 100)
    assert_equal(result[1].value, 30)


@fieldwise_init
struct SCBorrowedUpdate[o: ImmOrigin](OnceUnary):
    var view: Span[Int, Self.o]
    comptime Arg = Span[Int, Self.o]
    comptime Out = Span[Int, Self.o]
    def call_once(deinit self, var state: Self.Arg) -> Self.Out: return self.view


@fieldwise_init
struct SCBorrowedFailure[o: ImmOrigin](OnceUnary):
    var view: Span[Int, Self.o]
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Span[Int, Self.o]
    def call_once(deinit self, var state: Int) raises Self.Error -> Int: raise self.view


def sc_borrowed(owner: List[Int]) raises:
    comptime View = Span[Int, origin_of(owner)]
    comptime S = State[View]
    comptime R = ReaderT[S, Int]
    comptime C = LiftStateful[R, S]
    var base = run[R](modify[C](SCBorrowedUpdate[origin_of(owner)](Span(owner))), 0)
    var result = run[S](base^, Span(owner))
    comptime assert type_of(result) == Tuple[NoneType, View]
    assert_equal(result[1][1], 12)
    var read = run[S](run[R](get[C](), 0), Span(owner))
    comptime assert type_of(read) == Tuple[View, View]
    assert_equal(read[0][0], 11)
    var written = run[S](run[R](put[C](Span(owner)), 0), Span(owner))
    assert_equal(written[1][0], 11)
    comptime T = ResultT[State[Int], String]
    comptime TC = LiftStateful[T, State[Int]]
    var pending = modify[TC](SCBorrowedFailure[origin_of(owner)](Span(owner)))
    try: _ = run[State[Int]](pending^, 1)
    except error:
        comptime assert type_of(error) == View
        assert_equal(error[0], 11)


@fieldwise_init
struct SCCopyState(Copyable):
    var value: Int
    var copies: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.copies = copy.copies
        self.copies[] += 1


def sc_copy_timing() raises:
    comptime S = State[SCCopyState]
    comptime R = ReaderT[S, Int]
    comptime T = ResultT[R, String]
    comptime C = LiftStateful[T, LiftStateful[R, S]]
    var copies = ArcPointer(0)
    var pending = run[R](get[C](), 0)
    assert_equal(copies[], 0)
    var result = run[S](pending^, SCCopyState(8, copies))
    assert_equal(copies[], 1)
    assert_equal(result[0]._ok().value.value, 8)
    assert_equal(result[1].value, 8)
    def update(var state: SCCopyState) -> SCCopyState:
        state.value += 3
        return state^
    var modified = run[S](run[R](modify[C](update), 0), SCCopyState(8, copies))
    assert_equal(copies[], 1)
    assert_equal(modified[1].value, 11)


def main() raises:
    for mode in range(3):
        var calls = ArcPointer(0)
        var captures = ArcPointer(0)
        var states = ArcPointer(0)
        sc_owned_case(calls, captures, states, mode)
        assert_equal(calls[], 0 if mode == 2 else 1)
        assert_equal(captures[], 1)
        assert_equal(states[], 0 if mode == 2 else 1)
    for abandon in range(2):
        var states = ArcPointer(0)
        sc_put_case(states, Bool(abandon))
        assert_equal(states[], 1 if abandon else 2)
    var states = ArcPointer(0)
    sc_two_move_states(states)
    assert_equal(states[], 3)
    sc_borrowed([11, 12])
    sc_copy_timing()
    print("Stateful capabilities: move-only state, drop-once captures, exact origins")
