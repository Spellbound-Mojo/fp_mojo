"""Writer selection transfers move-only logs and values without observation copies."""
from fp.effects import Writer, WriterT, Reader, writer
from fp.algebra import IdentityFamily, ListFamily
from fp.functions import pipeline
from test_writer_capabilities import WCOwnedLog, WCMoveLogMonoid
from test_state_outputs_owned import OutputOwner
from algebra_support.external import PublicMonad
from std.memory import ArcPointer
from std.testing import assert_equal


def main() raises:
    comptime assert not conforms_to(WCOwnedLog,Copyable)
    comptime assert not conforms_to(OutputOwner,Copyable)
    comptime W = Writer[WCMoveLogMonoid]
    for log_only in range(2):
        var logs = ArcPointer(0)
        var values = ArcPointer(0)
        var source = pipeline(writer[W,OutputOwner]((WCOwnedLog("log",logs),OutputOwner(7,values))))
        if log_only:
            var result = source^.run_log()
            assert_equal(values[],1)
            assert_equal(logs[],0)
            assert_equal(result.text,"log")
            _ = result^
        else:
            var result = source^.run_value()
            assert_equal(values[],0)
            assert_equal(logs[],1)
            assert_equal(result.value,7)
            _ = result^
        assert_equal(logs[],1)
        assert_equal(values[],1)

    comptime D = WriterT[Reader[Int],WCMoveLogMonoid]
    for log_only in range(2):
        for abandon in range(2):
            var logs = ArcPointer(0)
            var values = ArcPointer(0)
            var source = pipeline(writer[D,OutputOwner](Reader[Int].pure((WCOwnedLog("log",logs),OutputOwner(7,values)))))
            if log_only:
                var pending = source^.run_log()
                assert_equal(logs[],0)
                assert_equal(values[],0)
                if abandon: _ = pending^
                else:
                    var selected = pipeline(pending^).run(0)
                    assert_equal(logs[],0)
                    assert_equal(values[],1)
                    _ = selected^
            else:
                var pending = source^.run_value()
                assert_equal(logs[],0)
                assert_equal(values[],0)
                if abandon: _ = pending^
                else:
                    var selected = pipeline(pending^).run(0)
                    assert_equal(logs[],1)
                    assert_equal(values[],0)
                    _ = selected^
            assert_equal(logs[],1)
            assert_equal(values[],1)

    comptime F = WriterT[PublicMonad[IdentityFamily,1],WCMoveLogMonoid]
    for log_only in range(2):
        var logs = ArcPointer(0)
        var values = ArcPointer(0)
        var source = pipeline(writer[F,OutputOwner]((WCOwnedLog("log",logs),OutputOwner(7,values))))
        var code = 0
        try:
            if log_only: _ = source^.run_log()
            else: _ = source^.run_value()
        except error: code = error
        assert_equal(code,702)
        assert_equal(logs[],1)
        assert_equal(values[],1)

    comptime M = WriterT[ListFamily,WCMoveLogMonoid]
    for log_only in range(2):
        var logs = ArcPointer(0)
        var values = ArcPointer(0)
        var items = List[Tuple[WCOwnedLog,OutputOwner]]()
        items.append((WCOwnedLog("one",logs),OutputOwner(1,values)))
        items.append((WCOwnedLog("two",logs),OutputOwner(2,values)))
        var source = pipeline(writer[M,OutputOwner](items^))
        if log_only:
            var selected = source^.run_log()
            assert_equal(len(selected),2)
            assert_equal(selected[1].text,"two")
            assert_equal(logs[],0)
            assert_equal(values[],2)
            _ = selected^
        else:
            var selected = source^.run_value()
            assert_equal(len(selected),2)
            assert_equal(selected[1].value,2)
            assert_equal(logs[],2)
            assert_equal(values[],0)
            _ = selected^
        assert_equal(logs[],2)
        assert_equal(values[],2)
