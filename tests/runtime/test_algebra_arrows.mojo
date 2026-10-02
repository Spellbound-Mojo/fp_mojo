from fp.algebra import pure, map, flat_map, IdentityFamily, ResultFamily
from fp.algebra import map2
from fp.effects import Reader, ReaderT, State, StateT, run, ask, get, put, modify, lift
from fp.callables import as_unary
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from algebra_support import Add, increment as inc

def reader_next(var x: Int) -> type_of(pure[Reader[Int]](Int())):
    return pure[Reader[Int]](x+2)

def state_next(var x: Int) -> type_of(pure[State[Int]](Int())):
    return pure[State[Int]](x+3)

def main() raises:
    var env = 7
    assert_equal(run[Reader[Int]](pure[Reader[Int]](5),env),5)
    assert_equal(run[Reader[Int]](ask[Reader[Int]](),env),7)
    assert_equal(run[Reader[Int]](map[Reader[Int]](as_unary(inc),ask[Reader[Int]]()),env),8)
    assert_equal(run[Reader[Int]](flat_map[Reader[Int]](as_unary(reader_next),ask[Reader[Int]]()),env),9)
    var p = run[State[Int]](pure[State[Int]](5),env)
    assert_equal(p[0],5)
    assert_equal(p[1],7)
    p = run[State[Int]](get[State[Int]](),env)
    assert_equal(p[0],7)
    p = run[State[Int]](map[State[Int]](as_unary(inc),get[State[Int]]()),env)
    assert_equal(p[0],8)
    p = run[State[Int]](flat_map[State[Int]](as_unary(state_next),get[State[Int]]()),env)
    assert_equal(p[0],10)
    assert_equal(run[State[Int]](put[State[Int]](8),env)[1],8)
    assert_equal(run[State[Int]](modify[State[Int]](as_unary(inc)),env)[1],8)
    p = run[State[Int]](lift[State[Int]](9),env)
    assert_equal(p[0],9)
    assert_equal(run[Reader[Int]](map2[Reader[Int]](Add(),ask[Reader[Int]](),ask[Reader[Int]]()),env),14)
    p = run[State[Int]](map2[State[Int]](Add(),get[State[Int]](),get[State[Int]]()),env)
    assert_equal(p[0],14)
    comptime SR = StateT[ResultFamily[Error],Int]
    var fail = run[SR](lift[SR](Result[Int,Error](Err(Error("bad")))),env)
    assert_equal(fail.is_err(),True)
    print("arrows ok")
