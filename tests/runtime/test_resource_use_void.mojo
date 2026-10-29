"""Body-free execution preserves native errors and nested release order."""
from test_resource_scopes import scope, ScopeIssue
from fp.effects import EffectFailure
from fp.data import Result
from std.memory import ArcPointer
from std.testing import assert_equal


def main() raises:
    for acquire_fail in range(2):
        for release_fail in range(2):
            var log = ArcPointer(List[Int]())
            var result = scope(1,Bool(acquire_fail),Bool(release_fail),log).use_void()
            comptime assert type_of(result) == Result[NoneType,EffectFailure[ScopeIssue]]
            assert_equal(log[],List[Int]([1]) if acquire_fail else List[Int]([1,-1]))
            assert_equal(result.is_err(),Bool(acquire_fail or release_fail))
            if result.is_err():
                var failure = result^._take_err()
                assert_equal(len(failure.errors),1)
                assert_equal(failure.errors.first().code,1 if acquire_fail else -1)
    var log = ArcPointer(List[Int]())
    var pair = scope(1,False,False,log).product(scope(2,False,False,log))
    var success = pair^.use_void()
    assert_equal(success.is_ok(),True)
    assert_equal(log[],List[Int]([1,2,-2,-1]))
    log[] = List[Int]()
    var partial = scope(1,False,True,log).product(scope(2,True,False,log)).use_void()
    assert_equal(log[],List[Int]([1,2,-1]))
    var failure = partial^._take_err()
    var errors = failure^.into_errors().into_list()
    assert_equal(len(errors),2)
    assert_equal(errors[0].code,2)
    assert_equal(errors[1].code,-1)
