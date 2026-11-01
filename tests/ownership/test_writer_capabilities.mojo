"""Log scopes preserve native moves, copy timing, borrows and error origins."""
from fp.algebra import Monoid, StringMonoid
from fp.effects import Writer, ReaderT, StateT, OptionalT, ResultT, LiftCensor, writer, tell, listen, censor, run, run_writer
from fp.callables import OnceUnary
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct WCOwnedLog(Movable):
    var text: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


struct WCMoveLogMonoid(Monoid):
    comptime Value = WCOwnedLog
    @staticmethod
    def empty() -> WCOwnedLog: return WCOwnedLog(String(), ArcPointer(0))
    @staticmethod
    def combine(var left: WCOwnedLog, var right: WCOwnedLog) -> WCOwnedLog:
        left.text += right.text
        return left^


@fieldwise_init
struct WCCapture(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct WCOnce(OnceUnary):
    var capture: WCCapture
    var calls: ArcPointer[Int]
    var fail: Bool
    comptime Arg = WCOwnedLog
    comptime Out = WCOwnedLog
    comptime Error = Int
    def call_once(deinit self, var log: WCOwnedLog) raises Int -> WCOwnedLog:
        self.calls[] += 1
        if self.fail: raise 71
        log.text += "!"
        return log^


@fieldwise_init
struct WCMoveState(Movable):
    var value: Int


def wc_owned_case(calls: ArcPointer[Int], captures: ArcPointer[Int], logs: ArcPointer[Int], mode: Int) raises:
    comptime W = Writer[WCMoveLogMonoid]
    comptime R = ReaderT[W, Int]
    comptime S = StateT[R, WCMoveState]
    comptime T = OptionalT[S]
    comptime C = LiftCensor[T, LiftCensor[S, LiftCensor[R, W]]]
    var source = tell[C](WCOwnedLog(String("a"), logs))
    comptime assert not C.ListenCompatible[type_of(source)]
    var pending = censor[C](source^, WCOnce(WCCapture(captures), calls, mode == 1))
    comptime assert not conforms_to(type_of(pending), Copyable)
    assert_equal(calls[], 0)
    if mode == 2:
        _ = pending^
        return
    var base = run[S](pending^, WCMoveState(42))
    assert_equal(calls[], 0)
    var succeeded = False
    var code = 0
    try:
        var result = run_writer[W](run[R](base^, 0))
        succeeded = result[0].text == "a!" and Bool(result[1][0]) and result[1][1].value == 42
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(succeeded, mode == 0)
    assert_equal(code, 71 if mode == 1 else 0)


@fieldwise_init
struct WCCopyLog(Copyable):
    var text: String
    var copies: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.text = copy.text.copy()
        self.copies = copy.copies
        self.copies[] += 1


struct WCCopyLogMonoid(Monoid):
    comptime Value = WCCopyLog
    @staticmethod
    def empty() -> WCCopyLog: return WCCopyLog(String(), ArcPointer(0))
    @staticmethod
    def combine(var left: WCCopyLog, var right: WCCopyLog) -> WCCopyLog:
        left.text += right.text
        return left^


def wc_listen_copies() raises:
    comptime W = Writer[WCCopyLogMonoid]
    comptime R = ReaderT[W, Int]
    comptime S = StateT[R, WCMoveState]
    comptime T = ResultT[S, String]
    comptime C = LiftCensor[T, LiftCensor[S, LiftCensor[R, W]]]
    var copies = ArcPointer(0)
    var payload = writer[W, WCMoveState](Tuple(WCCopyLog(String("a"), copies), WCMoveState(7)))
    var pending = listen[C](T.lift(S.lift(R.lift(payload^))))
    assert_equal(copies[], 0)
    var base = run[S](pending^, WCMoveState(42))
    assert_equal(copies[], 0)
    var result = run_writer[W](run[R](base^, 0))
    assert_equal(copies[], 1)
    assert_equal(result[0].text, "a")
    assert_equal(result[1][0]._ok().value[1].text, "a")
    assert_equal(result[1][0]._ok().value[0].value, 7)
    assert_equal(result[1][1].value, 42)


struct WCViewMonoid[o: ImmOrigin](Monoid):
    comptime Value = Optional[Span[Int, Self.o]]
    @staticmethod
    def empty() -> Self.Value: return None
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) -> Self.Value:
        if right: return right^
        return left^


@fieldwise_init
struct WCViewIdentity[o: ImmOrigin](OnceUnary, Defaultable):
    comptime Arg = Optional[Span[Int, Self.o]]
    comptime Out = Self.Arg
    def call_once(deinit self, var log: Self.Arg) -> Self.Out: return log^


@fieldwise_init
struct WCReject[o: ImmOrigin](OnceUnary):
    var view: Span[Int, Self.o]
    comptime Arg = String
    comptime Out = String
    comptime Error = Span[Int, Self.o]
    def call_once(deinit self, var log: String) raises Self.Error -> String: raise self.view


def wc_borrowed(owner: List[Int]) raises:
    comptime View = Span[Int, origin_of(owner)]
    comptime W = Writer[WCViewMonoid[origin_of(owner)]]
    comptime S = StateT[W, Int]
    comptime C = LiftCensor[S, W]
    var source = S.lift(writer[W, View](Tuple(Optional(Span(owner)), Span(owner))))
    var result = run_writer[W](run[S](listen[C](censor[C](source^, WCViewIdentity[origin_of(owner)]())), 42))
    comptime assert type_of(result) == Tuple[Optional[View], Tuple[Tuple[View, Optional[View]], Int]]
    assert_equal(result[0].value()[0], 11)
    assert_equal(result[1][0][0][1], 12)
    assert_equal(result[1][0][1].value()[0], 11)
    assert_equal(result[1][1], 42)

    comptime Plain = Writer[StringMonoid]
    comptime R = ReaderT[Plain, Int]
    comptime RC = LiftCensor[R, Plain]
    var pending = censor[RC](tell[RC](String("a")), WCReject[origin_of(owner)](Span(owner)))
    try: _ = run[R](pending^, 0)
    except error:
        comptime assert type_of(error) == View
        assert_equal(error[1], 12)


def main() raises:
    for mode in range(3):
        var calls = ArcPointer(0)
        var captures = ArcPointer(0)
        var logs = ArcPointer(0)
        wc_owned_case(calls, captures, logs, mode)
        assert_equal(calls[], 0 if mode == 2 else 1)
        assert_equal(captures[], 1)
        assert_equal(logs[], 1)
    wc_listen_copies()
    wc_borrowed([11, 12])
    print("Writer capabilities: move-only logs/state, one observation copy, exact origins")
