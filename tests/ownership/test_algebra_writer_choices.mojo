"""Recursive Writer choice elimination consumes one move-only leaf."""
from fp.algebra import pure, map, StringMonoid
from fp.effects import Reader, WriterT, run, run_writer
from fp.functions import Identity
from std.memory import ArcPointer
from std.testing import assert_equal
from test_attempt_once import Trace, Token

comptime R=Reader[Int]
comptime W=WriterT[R,StringMonoid]
comptime Same=Identity[Token[2]]
comptime P=W.Pure[Token[2]]
comptime M=W.Mapped[P,Same]
comptime Pair=W._Joined[P,M]
comptime Tree=W._Joined[Pair,M]


def choose(which:Int,trace:ArcPointer[Trace])->Tree:
    var leaf=pure[W](Token[2](7,trace))
    if which==0:
        return W._join_left[Pair,M](W._join_left[P,M](leaf^))
    var mapped=map[W](Identity[Token[2]](),leaf^)
    if which==1:
        return W._join_left[Pair,M](W._join_right[P,M](mapped^))
    return W._join_right[Pair,M](mapped^)


def main() raises:
    for which in range(3):
        var trace=ArcPointer(Trace(0,SIMD[DType.int64,4](0)))
        var environment=10
        var output=run[R](run_writer[W](choose(which,trace)),environment)
        var actual=output[1].value
        _=output^
        assert_equal(actual,7)
        assert_equal(trace[].drops[2],1)
    print("nested Writer choices: every branch consumes and destroys its move-only payload once")
