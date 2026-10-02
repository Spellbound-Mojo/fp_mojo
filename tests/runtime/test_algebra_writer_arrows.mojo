"""Reader and State over Writer use the same base log and arrow operations."""
from fp.algebra import flat_map, map2, StringMonoid
from fp.effects import Writer, ReaderT, StateT, writer, run_writer, run, lift, ask, get, put, listen, censor
from fp.callables import as_unary
from std.testing import assert_equal
from algebra_support import Add
from test_algebra_writer import tag

comptime W=Writer[StringMonoid]
comptime R=ReaderT[W,Int]
comptime S=StateT[W,Int]


def reader_next(var value:Int)->type_of(map2[R](Add(),lift[R](writer[W,Int](Tuple(String(),0))),ask[R]())):
    return map2[R](Add(),lift[R](writer[W,Int](Tuple(String("b"),value))),ask[R]())


def read_state(var unused:NoneType)->type_of(get[S]()):
    return get[S]()


def state_next(var value:Int)->type_of(map2[S](Add(),lift[S](writer[W,Int](Tuple(String(),0))),flat_map[S](as_unary(read_state),put[S](0)))):
    return map2[S](Add(),lift[S](writer[W,Int](Tuple(String("b"),value))),flat_map[S](as_unary(read_state),put[S](value+1)))


def check_reader() raises:
    var environment=10
    var computation=flat_map[R](as_unary(reader_next),map2[R](Add(),lift[R](writer[W,Int](Tuple(String("a"),2))),ask[R]()))
    var output=run_writer[W](listen[W](censor[W](as_unary(tag),run[R](computation^,environment))))
    assert_equal(output[0],"ab!")
    assert_equal(output[1][0],22)
    assert_equal(output[1][1],"ab!")
    assert_equal(environment,10)


def check_state() raises:
    var computation=flat_map[S](as_unary(state_next),map2[S](Add(),get[S](),lift[S](writer[W,Int](Tuple(String("a"),2)))))
    var output=run_writer[W](run[S](computation^,10))
    assert_equal(output[0],"ab")
    assert_equal(output[1][0],25)
    assert_equal(output[1][1],13)


def main() raises:
    check_reader()
    print("Reader over Writer: shared environment, bind, lift, ordered logs, listen, censor")
