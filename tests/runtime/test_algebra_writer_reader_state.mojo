"""Reader feeds a State computation whose base owns the Writer log."""
from fp.algebra import flat_map, map2
from fp.effects import ReaderT, ask, get, lift, writer, run, run_writer
from fp.callables import as_unary
from std.testing import assert_equal
from test_algebra_writer_arrows import W, S, state_next
from algebra_support import Add

comptime R=ReaderT[S,Int]

def main() raises:
    var environment=12
    var initial=map2[S](Add(),get[S](),lift[S](writer[W,Int](Tuple(String("a"),2))))
    var computation=map2[R](Add(),ask[R](),lift[R](initial^))
    var stateful=run[R](computation^,environment)
    var updated=flat_map[S](as_unary(state_next),stateful^)
    var output=run_writer[W](run[S](updated^,10))
    assert_equal(output[0],"ab")
    assert_equal(output[1][0],49)
    assert_equal(output[1][1],25)
    assert_equal(environment,12)
    print("Reader/State/Writer: environment-driven state update and ordered log")
