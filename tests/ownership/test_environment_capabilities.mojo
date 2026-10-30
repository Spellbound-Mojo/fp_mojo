"""Scopes preserve move-only environments, captures, state, and external origins."""
from fp.effects import Reader, ReaderT, StateT, LiftLocal, action, local, run, ask
from fp.callables import BorrowCallable, BorrowOnceCallable, as_unary
from fp.algebra import flat_map
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct ECEnv(Movable):
    var value: Int


@fieldwise_init
struct ECReadEnv(BorrowCallable, Defaultable):
    comptime Payload = ECEnv
    comptime Result = Int
    def invoke(self, ref env: ECEnv) raises Never capturing -> Int: return env.value


@fieldwise_init
struct ECCapture(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct ECChangeOnce(BorrowOnceCallable):
    var capture: ECCapture
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Payload = ECEnv
    comptime Result = ECEnv
    comptime Failure = Int
    def invoke_once(deinit self, ref env: ECEnv) raises Int capturing -> ECEnv:
        self.calls[] += 1
        if self.fail: raise 71
        return ECEnv(env.value + 3)


@fieldwise_init
struct ECMoveState(Movable):
    var value: Int


def scoped_case(calls: ArcPointer[Int], drops: ArcPointer[Int], mode: Int) raises:
    comptime R = Reader[ECEnv]
    comptime S = StateT[R, ECMoveState]
    comptime C = LiftLocal[S, R]
    comptime assert not C.AskAvailable
    var pending = local[C](S.lift(action[R, Int](ECReadEnv())), ECChangeOnce(ECCapture(drops), calls, mode == 1))
    comptime assert not conforms_to(type_of(pending), Copyable)
    assert_equal(calls[], 0)
    if mode == 2:
        _ = pending^
        return
    var base = run[S](pending^, ECMoveState(42))
    assert_equal(calls[], 0)
    var env = ECEnv(5)
    var pair: Tuple[Int, ECMoveState]
    try:
        pair = run[R](base^, env)
    except error:
        comptime assert type_of(error) == Int
        assert_equal(error, 71)
        assert_equal(mode, 1)
        assert_equal(env.value, 5)
        return
    assert_equal(pair[0], 8)
    assert_equal(pair[1].value, 42)
    assert_equal(mode, 0)
    assert_equal(env.value, 5)


def borrowed_environment(owner: List[Int]) raises:
    comptime View = Span[Int, origin_of(owner)]
    comptime R = Reader[View]
    comptime S = StateT[R, Int]
    comptime C = LiftLocal[S, R]
    def same(value: View) -> View: return value
    var env = Span(owner)
    var base = run[S](local[C](ask[C](), same), 9)
    var pair = run[R](base^, env)
    assert_equal(pair[0][1], 12)
    assert_equal(pair[1], 9)


@fieldwise_init
struct ECReject[o: ImmOrigin](BorrowOnceCallable):
    var view: Span[Int, Self.o]
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = Span[Int, Self.o]
    def invoke_once(deinit self, ref value: Int) raises Self.Failure capturing -> Int:
        raise self.view


def borrowed_error(owner: List[Int]) raises:
    comptime View = Span[Int, origin_of(owner)]
    comptime R = Reader[Int]
    comptime S = StateT[R, Int]
    comptime C = LiftLocal[S, R]
    var base = run[S](local[C](ask[C](), ECReject[origin_of(owner)](Span(owner))), 0)
    try:
        _ = run[R](base^, 5)
    except error:
        comptime assert type_of(error) == View
        assert_equal(error[0], 11)



def outer_borrow(owner: List[Int]) raises:
    comptime R = Reader[Int]
    comptime Outer = ReaderT[R, List[Int]]
    comptime Inner = LiftLocal[Outer, R]
    def read_again(var ignored: List[Int]) -> Outer.Asked: return ask[Outer]()
    def change_inner(value: Int) -> Int: return value + 10
    var source = flat_map[Outer](ask[Outer](), as_unary(read_again))
    var base = run[Outer](local[Inner](source^, change_inner), owner)
    var result = run[R](base^, 7)
    assert_equal(result, owner)

def main() raises:
    for mode in range(3):
        var calls = ArcPointer(0)
        var drops = ArcPointer(0)
        scoped_case(calls, drops, mode)
        assert_equal(calls[], 0 if mode == 2 else 1)
        assert_equal(drops[], 1)
    borrowed_environment([11, 12])
    borrowed_error([11, 12])
    outer_borrow([11, 12])
    print("Environment capabilities: ownership, timing, borrowed payloads and errors")
