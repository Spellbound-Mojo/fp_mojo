"""IO execution without a body remains deferred and observes cancellation."""
from test_io_resources import ResourceStep, ResourceRelease
from fp.effects import IOContract, Outcome, CancellationToken, delay, resource_io_case
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal


def main() raises:
    for mode in range(7):
        var log = ArcPointer(List[Int]())
        var token = CancellationToken()
        var acquire = delay[Int](ResourceStep(log,token.copy(),1,mode == 1,mode == 3))
        var release = ResourceRelease(ResourceStep(log,token.copy(),3,mode == 2 or mode == 4,mode == 4),0)
        var program = resource_io_case(acquire^,release^).use_void()
        comptime assert IOContract[type_of(program)].Compatible
        comptime assert IOContract[type_of(program)].Error == Int
        comptime assert type_of(program).Value == NoneType
        assert_equal(len(log[]),0)
        if mode == 6:
            _ = program^
            assert_equal(len(log[]),0)
            continue
        if mode == 5: token.cancel()
        var outcome = pipeline(program^).run_io(token)
        comptime assert type_of(outcome) == Outcome[NoneType,Int]
        if mode == 5:
            assert_equal(Bool(outcome),False)
            assert_equal(len(log[]),0)
        elif mode == 1:
            assert_equal(log[],List[Int]([1]))
            var result = outcome.take()
            var failure = result^._take_err()
            assert_equal(failure^.into_errors().into_list(),List[Int]([1]))
        elif mode == 3:
            assert_equal(Bool(outcome),False)
            assert_equal(log[],List[Int]([1,200,3]))
        else:
            assert_equal(log[],List[Int]([1,3]))
            var result = outcome.take()
            assert_equal(result.is_err(),mode == 2 or mode == 4)
            if result.is_err():
                var failure = result^._take_err()
                assert_equal(failure.canceled,mode == 4)
                assert_equal(failure^.into_errors().into_list(),List[Int]([3]))
