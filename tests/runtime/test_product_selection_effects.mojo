"""Selected payloads preserve deferred execution and exact family errors."""
from fp.algebra import pure
from fp.algebra.contracts import ProductLeftContract, ProductRightContract
from fp.functions import pipeline
from fp.effects import Reader, State, Writer, WriterT, IO, get, modify, writer, delay
from test_context_product_contract_errors import FailingLog
from std.testing import assert_equal
from std.memory import ArcPointer


def increment(state: Int) -> Int: return state + 1

def main() raises:
    comptime S = State[Int]
    assert_equal(pipeline(modify[S](increment)).product_r(get[S]()).run(10),(11,11))
    assert_equal(pipeline(get[S]()).product_l(modify[S](increment)).run(10),(10,11))
    comptime R = Reader[Int]
    var calls = ArcPointer(0)
    def first(value: Int) {calls} -> Int:
        calls[] = calls[] * 10 + 1
        return value + 1
    def second(value: Int) {calls} -> Int:
        calls[] = calls[] * 10 + 2
        return value + 2
    var pending = pipeline(pure[R](3)).map(first).product_r(pipeline(pure[R](3)).map(second).get())
    assert_equal(calls[],0)
    assert_equal(pending^.run(0),5)
    assert_equal(calls[],12)
    comptime Eager = Writer[FailingLog]
    comptime Deferred = WriterT[R,FailingLog]
    comptime for retain_left in range(2):
        var code = 0
        try:
            var left = writer[Eager,Int]((0,1))
            var right = writer[Eager,String]((0,String("right")))
            comptime assert ProductLeftContract[Eager,type_of(left),type_of(right)].Error == Int
            comptime assert ProductRightContract[Eager,type_of(left),type_of(right)].Error == Int
            comptime if retain_left:
                _ = pipeline(left^).product_l(right^).run()
            else:
                _ = pipeline(left^).product_r(right^).run()
        except error:
            comptime assert type_of(error) == Int
            code = error
        assert_equal(code,77)
        code = 0
        var constructed: Bool
        try:
            var left = writer[Deferred,Int](R.pure((0,1)))
            var right = writer[Deferred,String](R.pure((0,String("right"))))
            comptime assert ProductLeftContract[Deferred,type_of(left),type_of(right)].Error == Never
            comptime assert ProductRightContract[Deferred,type_of(left),type_of(right)].Error == Never
            comptime if retain_left:
                var selected = pipeline(left^).product_l(right^).run()
                constructed = True
                _ = pipeline(selected^).run(0)
            else:
                var selected = pipeline(left^).product_r(right^).run()
                constructed = True
                _ = pipeline(selected^).run(0)
        except error:
            comptime assert type_of(error) == Int
            code = error
        assert_equal(constructed,True)
        assert_equal(code,77)
    var order = ArcPointer(0)
    def io_left() raises Int {order} -> Int:
        order[] = order[] * 10 + 1
        raise 81
    def io_right() {order} -> Int:
        order[] = order[] * 10 + 2
        return 9
    var failed = pipeline(delay[Int](io_left)).product_r(delay[Int](io_right))
    assert_equal(order[],0)
    var result = failed^.run_io()
    assert_equal(Bool(result),True)
    var stored = result.take()
    assert_equal(stored.is_err(),True)
    var failure = stored^._take_err()
    assert_equal(failure^.into_errors().into_list(),List[Int]([81]))
    assert_equal(order[],1)
    order[] = 0
    def io_success() {order} -> Int:
        order[] = order[] * 10 + 1
        return 7
    var success = pipeline(delay[Int](io_success)).product_l(delay[Int](io_right))
    assert_equal(order[],0)
    var completed = success^.run_io()
    var outcome = completed.take()
    assert_equal(outcome._ok().value,7)
    assert_equal(order[],12)
