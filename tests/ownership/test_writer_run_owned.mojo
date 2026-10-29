"""The unified Writer runner transfers owners and keeps deferred cleanup timing."""
from fp.effects import Writer, WriterT, Reader, writer, run, run_writer
from fp.functions import pipeline
from test_writer_capabilities import WCOwnedLog, WCMoveLogMonoid
from test_state_outputs_owned import OutputOwner
from std.memory import ArcPointer
from std.testing import assert_equal


def main() raises:
    comptime W = Writer[WCMoveLogMonoid]
    comptime D = WriterT[Reader[Int],WCMoveLogMonoid]
    for mode in range(3):
        var logs = ArcPointer(0)
        var values = ArcPointer(0)
        var source = writer[W,OutputOwner]((WCOwnedLog("log",logs),OutputOwner(7,values)))
        var pair: Tuple[WCOwnedLog,OutputOwner]
        if mode == 0: pair = run[W](source^)
        elif mode == 1: pair = run_writer[W](source^)
        else: pair = pipeline(source^).run()
        assert_equal(logs[],0)
        assert_equal(values[],0)
        assert_equal(pair[0].text,"log")
        assert_equal(pair[1].value,7)
        _ = pair^
        assert_equal(logs[],1)
        assert_equal(values[],1)

    for abandon in range(2):
        var logs = ArcPointer(0)
        var values = ArcPointer(0)
        var source = writer[D,OutputOwner](Reader[Int].pure((WCOwnedLog("later",logs),OutputOwner(11,values))))
        var pending = run[D](source^)
        assert_equal(logs[],0)
        assert_equal(values[],0)
        if abandon: _ = pending^
        else:
            var pair = run[Reader[Int]](pending^,0)
            assert_equal(logs[],0)
            assert_equal(values[],0)
            assert_equal(pair[0].text,"later")
            assert_equal(pair[1].value,11)
            _ = pair^
        assert_equal(logs[],1)
        assert_equal(values[],1)
