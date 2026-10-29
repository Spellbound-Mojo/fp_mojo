"""Scoped callbacks keep move-only inputs, captures, copies and origins intact."""
from fp.functions import pipeline
from fp.effects import Reader, Writer, WriterT, action, writer
from fp.algebra import StringMonoid
from test_environment_capabilities import ECEnv, ECReadEnv, ECChangeOnce, ECCapture
from test_writer_capabilities import WCOwnedLog, WCMoveLogMonoid, WCCapture, WCOnce, WCCopyLog, WCCopyLogMonoid, WCViewMonoid, WCViewIdentity, WCReject
from std.memory import ArcPointer
from std.testing import assert_equal

def local_case(mode: Int) raises:
    comptime R = Reader[ECEnv]
    var calls = ArcPointer(0)
    var drops = ArcPointer(0)
    var pending = pipeline(action[R,Int](ECReadEnv())).local(ECChangeOnce(ECCapture(drops), calls, mode == 1))
    assert_equal(calls[], 0)
    if mode == 2:
        _ = pending^
    else:
        var env = ECEnv(5)
        var result = 0
        var error_code = 0
        try:
            result = pending^.run(env)
        except error:
            comptime assert type_of(error) == Int
            error_code = error
        assert_equal(result, 8 if mode == 0 else 0)
        assert_equal(error_code, 71 if mode == 1 else 0)
        assert_equal(env.value, 5)
    assert_equal(calls[], 0 if mode == 2 else 1)
    assert_equal(drops[], 1)

def censor_case(mode: Int) raises:
    comptime R = Reader[Int]
    comptime W = WriterT[R, WCMoveLogMonoid]
    var calls = ArcPointer(0)
    var captures = ArcPointer(0)
    var logs = ArcPointer(0)
    var pending = pipeline(writer[W,Int](R.pure((WCOwnedLog("a", logs),7)))).censor(WCOnce(WCCapture(captures), calls, mode == 1))
    assert_equal(calls[], 0)
    if mode == 2:
        _ = pending^
    else:
        var base = pending^.run()
        assert_equal(calls[], 0)
        var text = String()
        var error_code = 0
        try:
            var result = pipeline(base^).run(0)
            text = result[0].text.copy()
            _ = result^
        except error:
            comptime assert type_of(error) == Int
            error_code = error
        assert_equal(text, "a!" if mode == 0 else "")
        assert_equal(error_code, 71 if mode == 1 else 0)
    assert_equal(calls[], 0 if mode == 2 else 1)
    assert_equal(captures[], 1)
    assert_equal(logs[], 1)

def listen_copy() raises:
    comptime R = Reader[Int]
    comptime W = WriterT[R, WCCopyLogMonoid]
    var copies = ArcPointer(0)
    var pending = pipeline(writer[W,Int](R.pure((WCCopyLog("a",copies),7)))).listen()
    assert_equal(copies[], 0)
    var base = pending^.run()
    assert_equal(copies[], 0)
    var result = pipeline(base^).run(0)
    assert_equal(copies[], 1)
    assert_equal(result[0].text, "a")
    assert_equal(result[1][0], 7)
    assert_equal(result[1][1].text, "a")

def borrowed(owner: List[Int]) raises:
    comptime View = Span[Int,origin_of(owner)]
    comptime W = Writer[WCViewMonoid[origin_of(owner)]]
    var source = writer[W,View]((Optional(Span(owner)),Span(owner)))
    var result = pipeline(source^).censor(WCViewIdentity[origin_of(owner)]()).listen().run()
    comptime assert type_of(result) == Tuple[Optional[View],Tuple[View,Optional[View]]]
    assert_equal(Pointer(to=result[1][0][0]) == Pointer(to=owner[0]), True)
    var caught = False
    try:
        _ = pipeline(Writer[StringMonoid].pure(3)).censor(WCReject(Span(owner))).run()
    except error:
        comptime assert type_of(error) == View
        caught = error[0] == 7
    assert_equal(caught, True)

def main() raises:
    for mode in range(3):
        local_case(mode)
        censor_case(mode)
    listen_copy()
    borrowed([7,11])
