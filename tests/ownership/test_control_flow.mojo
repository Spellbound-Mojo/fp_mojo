"""Control-flow receiver state, move-only values, typed failures and cleanup."""
from fp.control import while_loop, fori_loop, scan, ScanStepError, ScanLengthError
from fp.callables import BorrowCallable, Unary
from algebra_support import split_pair
from std.builtin.rebind import rebind_var
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from test_attempt_once import Trace, Token


def under(value: Token[1]) -> Bool:
    value.trace[].calls += 1
    return value.value < 3


def increase(var value: Token[1]) -> Token[1]:
    value.value += 1
    return value^


def indexed(var index: Int, var value: Token[1]) -> Token[1]:
    value.value += index
    return value^


def token_emit(var carry: Token[1], var item: Token[2]) -> Tuple[Token[1], Token[3]]:
    carry.value += item.value
    return (carry^, Token[3](item.value, item.trace))


def token_failure(var carry: Token[1], var item: Token[2]) raises Token[2] -> Tuple[Token[1], Token[3]]:
    if item.value == 3:
        raise item^
    return token_emit(carry^, item^)


def items(trace: ArcPointer[Trace]) -> List[Token[2]]:
    var values = List[Token[2]]()
    for index in range(1, 5):
        values.append(Token[2](index, trace))
    return values^


def successful(trace: ArcPointer[Trace]) raises:
    var carried = while_loop(under, increase, Token[1](0, trace))
    assert_equal(carried.value, 3)
    assert_equal(trace[].calls, 4)
    var counted = fori_loop[unroll=3](0, 4, indexed, carried^)
    assert_equal(counted.value, 9)
    var result = scan(token_emit, counted^, items(trace), reverse=True)
    var first = Optional[Token[1]]()
    var second = Optional[List[Token[3]]]()
    split_pair(result^, first, second)
    var final_carry = first.take()
    var outputs = second.take()
    assert_equal(final_carry.value, 19)
    assert_equal(len(outputs), 4)
    assert_equal(outputs[0].value, 1)
    assert_equal(outputs[3].value, 4)
    assert_equal(trace[].drops[1], 0)
    assert_equal(trace[].drops[2], 4)
    assert_equal(trace[].drops[3], 0)
    assert_equal(final_carry.value, 19)
    assert_equal(outputs[0].value, 1)


def failing(trace: ArcPointer[Trace]) raises:
    var caught = False
    try:
        _ = scan(token_failure, Token[1](0, trace), items(trace))
    except error:
        caught = True
        assert_true(error.isa[ScanStepError[Token[2]]]())
        assert_equal(error[ScanStepError[Token[2]]].error.value, 3)
        assert_equal(trace[].drops[1], 1)
        # Current error still owns one input; the unprocessed fourth input is gone.
        assert_equal(trace[].drops[2], 3)
        assert_equal(trace[].drops[3], 2)
        assert_equal(error[ScanStepError[Token[2]]].error.value, 3)
    assert_true(caught)
    assert_equal(trace[].drops[2], 4)


@fieldwise_init
struct Increment(Unary):
    var calls: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = Int
    def call(self, var value: Int) -> Int:
        self.calls[] += 1
        return value + 1


@fieldwise_init
struct Predicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    def invoke(self, ref value: Int) capturing -> Bool:
        return value < 3


@fieldwise_init
struct Sequence(Iterator, Movable):
    var next: Int
    var pulls: ArcPointer[Int]
    comptime Element = Int
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[] += 1
        if self.next == 4:
            raise StopIteration()
        var result = self.next
        self.next += 1
        return result


def stateful() raises:
    # A library body keeps one receiver; its state lives behind a shared handle.
    var increments = ArcPointer(0)
    assert_equal(while_loop(Predicate(), Increment(increments), 0), 3)
    assert_equal(increments[], 3)
    var body_calls = 3
    def indexed_step(var index: Int, var value: Int) {mut body_calls} -> Int:
        body_calls += 1
        return value + body_calls + index
    assert_equal(fori_loop[unroll=3](0, 4, indexed_step, 0), 28)
    assert_equal(body_calls, 7)
    var calls = 0
    def step(var carry: Int, var value: Int) {mut calls} -> Tuple[Int, Int]:
        calls += 1
        return (carry + value, calls)
    var outputs = scan[unroll=3](step, 0, iter(range(5)))
    assert_equal(calls, 5)
    assert_equal(outputs[1][0], 1)
    assert_equal(outputs[1][4], 5)
    # Validation drains the finite source, but invokes no callbacks on mismatch.
    var pulls = ArcPointer(0)
    var old_calls = calls
    var caught = False
    try:
        _ = scan(step, 0, Sequence(0, pulls), length=2)
    except error:
        caught = True
        assert_equal(error.expected, 2)
        assert_equal(error.actual, 4)
    assert_true(caught)
    assert_equal(pulls[], 5)
    assert_equal(calls, old_calls)
    def stop(var carry: Int, var value: Int) raises StopIteration -> Tuple[Int, Int]:
        raise StopIteration()
    var stopped = False
    try:
        _ = scan(stop, 0, iter(range(3)))
    except error:
        stopped = error.isa[ScanStepError[StopIteration]]()
    assert_true(stopped)


def main() raises:
    var trace = ArcPointer(Trace(0, SIMD[DType.int64, 4](0)))
    successful(trace)
    assert_equal(trace[].drops[1], 1)
    assert_equal(trace[].drops[2], 4)
    assert_equal(trace[].drops[3], 4)
    trace = ArcPointer(Trace(0, SIMD[DType.int64, 4](0)))
    failing(trace)
    stateful()
