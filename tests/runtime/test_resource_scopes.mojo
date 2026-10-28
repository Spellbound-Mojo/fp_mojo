"""Resource ordering, all failure combinations, and deferred scope composition."""
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from fp.callables import OnceThunk, OnceUnary, BorrowCallable
from fp.effects.resources import resource, ResourceContract

@fieldwise_init
struct ScopeIssue(Movable):
    var code: Int

@fieldwise_init
struct ScopeAcquire(OnceThunk):
    var id: Int
    var fail: Bool
    var log: ArcPointer[List[Int]]
    comptime Out = Int
    comptime Error = ScopeIssue
    def call_once(deinit self) raises Self.Error -> Int:
        self.log[].append(self.id)
        if self.fail:
            raise ScopeIssue(self.id)
        return self.id

@fieldwise_init
struct ScopeRelease(OnceUnary):
    var fail: Bool
    var log: ArcPointer[List[Int]]
    comptime Arg = Int
    comptime Out = NoneType
    comptime Error = ScopeIssue
    def call_once(deinit self, var value: Int) raises Self.Error -> NoneType:
        self.log[].append(-value)
        if self.fail:
            raise ScopeIssue(-value)
        return None

@fieldwise_init
struct ScopeUse(BorrowCallable):
    var fail: Bool
    var log: ArcPointer[List[Int]]
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = ScopeIssue
    def invoke(self, ref value: Int) raises Self.Failure -> Int:
        self.log[].append(99)
        if self.fail:
            raise ScopeIssue(99)
        return value * 2

comptime ScopeRecipe = ResourceContract[ScopeAcquire, ScopeRelease, ScopeIssue].Out

def scope(id: Int, acquire_fail: Bool, release_fail: Bool, log: ArcPointer[List[Int]]) -> ScopeRecipe:
    return resource[ScopeIssue](ScopeAcquire(id, acquire_fail, log.copy()), ScopeRelease(release_fail, log.copy()))

@fieldwise_init
struct ScopeDerive(BorrowCallable):
    var fail: Bool
    var log: ArcPointer[List[Int]]
    comptime Payload = Int
    comptime Result = ScopeRecipe
    comptime Failure = ScopeIssue
    def invoke(self, ref value: Int) raises Self.Failure -> Self.Result:
        self.log[].append(77)
        if self.fail:
            raise ScopeIssue(77)
        return scope(value + 1, False, False, self.log)

def scope_pair_value(value: Tuple[Int, Int]) -> Int:
    return value[0] + value[1]

def main() raises:
    for acquire_fail in [False, True]:
        for use_fail in [False, True]:
            for release_fail in [False, True]:
                var log = ArcPointer(List[Int]())
                var recipe = scope(1, acquire_fail, release_fail, log)
                assert_equal(len(log[]), 0)
                var result = recipe^.use(ScopeUse(use_fail, log.copy()))
                if acquire_fail:
                    assert_equal(log[], [1])
                    var failure = result^._take_err()
                    assert_equal(len(failure.errors), 1)
                    assert_equal(failure.errors.first().code, 1)
                else:
                    assert_equal(log[], [1, 99, -1])
                    if use_fail or release_fail:
                        var failure = result^._take_err()
                        assert_equal(len(failure.errors), Int(use_fail) + Int(release_fail))
                        var stored = failure^.into_errors()
                        var errors = stored^.into_list()
                        assert_equal(errors[0].code, 99 if use_fail else -1)
                        if use_fail and release_fail:
                            assert_equal(errors[1].code, -1)
                    else:
                        assert_equal(result^._take_ok(), 2)

    var log = ArcPointer(List[Int]())
    _ = scope(1, False, False, log)
    assert_equal(len(log[]), 0)
    var pair = scope(1, False, False, log).product(scope(2, False, False, log))
    var paired = pair^.use(scope_pair_value)
    assert_equal(paired^._take_ok(), 3)
    assert_equal(log[], [1, 2, -2, -1])
    log[] = List[Int]()
    var partial = scope(1, False, True, log).product(scope(2, True, False, log))
    var failed = partial^.use(scope_pair_value)
    assert_equal(log[], [1, 2, -1])
    var failure = failed^._take_err()
    assert_equal(len(failure.errors), 2)
    var stored = failure^.into_errors()
    var errors = stored^.into_list()
    assert_equal(errors[0].code, 2)
    assert_equal(errors[1].code, -1)
    for factory_fail in [False, True]:
        log[] = List[Int]()
        var nested = scope(1, False, False, log).flat_map(ScopeDerive(factory_fail, log.copy()))
        var result = nested^.use(ScopeUse(False, log.copy()))
        if factory_fail:
            assert_true(result.is_err())
            assert_equal(log[], [1, 77, -1])
        else:
            assert_equal(result^._take_ok(), 4)
            assert_equal(log[], [1, 77, 2, 99, -2, -1])

    log[] = List[Int]()
    def project(value: Int) -> Int: return value + 10
    var mapped = scope(1, False, False, log).map(project)
    var projection = mapped^.use(ScopeUse(False, log.copy()))
    assert_equal(projection^._take_ok(), 22)
    assert_equal(log[], [1, 99, -1])
    log[] = List[Int]()
    var failed_projection = scope(1, False, True, log).map(ScopeUse(True, log.copy()))
    var projected_error = failed_projection^.use(ScopeUse(False, log.copy()))
    var projection_failure = projected_error^._take_err()
    assert_equal(len(projection_failure.errors), 2)
    assert_equal(log[], [1, 99, -1])
