"""Native and library terminal error types survive chained generic forwarding."""
from fp.iteration import iterated, ReductionError, ReductionStepError, EmptyReductionError
from fp.data import ControlFlow, Continue
from fp.callables import Binary, BorrowCallable
from std.iter import Iterator
from std.testing import assert_equal


@fieldwise_init
struct IteratedTerminalFault(Movable, Writable):
    var code: Int

def folded[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator,
           E: AnyType, //, F: def(var A, var T) raises E -> A](
    step: F, var initial: A, var source: I
) raises E -> A where I.Element == T:
    return iterated(source^).fold_left[E=E](step, initial^)

def reduced[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //,
            F: def(var T, var T) raises E -> T](step: F, var source: I
) raises ReductionError[E] -> T where I.Element == T:
    return iterated(source^).reduce[E=E](step)

@fieldwise_init
struct IteratedRaisingStep(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = IteratedTerminalFault
    def call(self, var first: Int, var second: Int) raises Self.Error -> Int:
        raise IteratedTerminalFault(second)

@fieldwise_init
struct IteratedRaisingPredicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    comptime Failure = IteratedTerminalFault
    def invoke(self, ref payload: Self.Payload) raises Self.Failure capturing -> Self.Result:
        raise IteratedTerminalFault(payload)

@fieldwise_init
struct IteratedRaisingControl(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = ControlFlow[Int, Int]
    comptime Error = IteratedTerminalFault
    def call(self, var first: Int, var second: Int) raises Self.Error -> Self.Out:
        raise IteratedTerminalFault(second)

def main() raises:
    for mode in range(7):
        var calls = 0
        def step(var total: Int, var value: Int) raises IteratedTerminalFault {mut calls} -> Int:
            calls += 1
            if value == 2:
                raise IteratedTerminalFault(42)
            return total + value
        def control(var total: Int, var value: Int) raises IteratedTerminalFault {mut calls} -> ControlFlow[Int, Int]:
            calls += 1
            if value == 2:
                raise IteratedTerminalFault(42)
            return Continue(total + value)
        def predicate(value: Int) raises IteratedTerminalFault {mode, mut calls} -> Bool:
            calls += 1
            if value == 2:
                raise IteratedTerminalFault(42)
            return mode == 6
        var caught = False
        try:
            if mode == 0:
                _ = folded(step, 0, range(1, 5))
            elif mode == 1:
                _ = iterated(range(1, 5)).reduce(step, initial=0)
            elif mode == 2:
                _ = iterated(range(0, 5)).reduce_optional(step)
            elif mode == 3:
                _ = iterated(range(1, 5)).fold_until(control, 0)
            elif mode == 4:
                _ = iterated(range(1, 5)).find(predicate)
            elif mode == 5:
                _ = iterated(range(1, 5)).any(predicate)
            else:
                _ = iterated(range(1, 5)).all(predicate)
        except error:
            comptime assert type_of(error) == IteratedTerminalFault
            assert_equal(error.code, 42)
            caught = True
        assert_equal(caught, True)
        assert_equal(calls, 2)

    def fail(var total: Int, var value: Int) raises IteratedTerminalFault -> Int:
        raise IteratedTerminalFault(value)
    for mode in range(3):
        var caught = False
        try:
            if mode == 0:
                _ = reduced(fail, range(2))
            elif mode == 1:
                _ = iterated(range(2)).reduce(IteratedRaisingStep())
            else:
                _ = reduced(fail, range(0))
        except error:
            comptime assert type_of(error) == ReductionError[IteratedTerminalFault]
            if mode == 2:
                assert_equal(error.isa[EmptyReductionError](), True)
            else:
                assert_equal(error.isa[ReductionStepError[IteratedTerminalFault]](), True)
                assert_equal(error^.unwrap[ReductionStepError[IteratedTerminalFault]]().into_error().code, 1)
            caught = True
        assert_equal(caught, True)

    for mode in range(7):
        var caught = False
        try:
            if mode == 0:
                _ = iterated(range(1, 5)).fold_left(IteratedRaisingStep(), 0)
            elif mode == 1:
                _ = iterated(range(1, 5)).reduce(IteratedRaisingStep(), initial=0)
            elif mode == 2:
                _ = iterated(range(0, 5)).reduce_optional(IteratedRaisingStep())
            elif mode == 3:
                _ = iterated(range(1, 5)).fold_until(IteratedRaisingControl(), 0)
            elif mode == 4:
                _ = iterated(range(1, 5)).find(IteratedRaisingPredicate())
            elif mode == 5:
                _ = iterated(range(1, 5)).any(IteratedRaisingPredicate())
            else:
                _ = iterated(range(1, 5)).all(IteratedRaisingPredicate())
        except error:
            comptime assert type_of(error) == IteratedTerminalFault
            assert_equal(error.code, 1)
            caught = True
        assert_equal(caught, True)

    # A callback's StopIteration is an error, never source exhaustion.
    def stopped(var total: Int, var value: Int) raises StopIteration -> Int:
        raise StopIteration()
    var propagated = False
    try:
        _ = iterated(range(3)).fold_left(stopped, 0)
    except error:
        comptime assert type_of(error) == StopIteration
        propagated = True
    assert_equal(propagated, True)
