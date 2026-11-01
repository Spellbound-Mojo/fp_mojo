"""Every callback, acquired value, success, and typed error has one owner."""
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from fp.callables import OnceThunk, OnceUnary, BorrowOnceCallable
from fp.effects.resources import resource
from fp.effects.io import delay, run_io, guarantee, CancellationToken

@fieldwise_init
struct ResourceLifeCounts(Movable):
    var created: Int
    var destroyed: Int
    var acquired: Int
    var released: Int
    var used: Int

struct ResourceOwner(Movable):
    var id: Int
    var counts: ArcPointer[ResourceLifeCounts]
    def __init__(out self, id: Int, var counts: ArcPointer[ResourceLifeCounts]):
        self.id = id
        self.counts = counts^
        self.counts[].created += 1
    def __deinit__(deinit self):
        self.counts[].destroyed += 1

@fieldwise_init
struct ResourceOwnedFailure(Movable):
    var owner: ResourceOwner

@fieldwise_init
struct OwnedScopeAcquire(OnceThunk):
    var capture: ResourceOwner
    var fail: Bool
    comptime Out = ResourceOwner
    comptime Error = ResourceOwnedFailure
    def call_once(deinit self) raises Self.Error -> Self.Out:
        self.capture.counts[].acquired += 1
        if self.fail:
            raise ResourceOwnedFailure(self.capture^)
        return ResourceOwner(10, self.capture.counts.copy())

@fieldwise_init
struct OwnedScopeRelease(OnceUnary):
    var capture: ResourceOwner
    var fail: Bool
    comptime Arg = ResourceOwner
    comptime Out = ResourceOwner
    comptime Error = ResourceOwnedFailure
    def call_once(deinit self, var value: Self.Arg) raises Self.Error -> Self.Out:
        self.capture.counts[].released += 1
        if self.fail:
            raise ResourceOwnedFailure(value^)
        return self.capture^

@fieldwise_init
struct OwnedScopeUse(BorrowOnceCallable):
    var capture: ResourceOwner
    var fail: Bool
    comptime Payload = ResourceOwner
    comptime Result = ResourceOwner
    comptime Failure = ResourceOwnedFailure
    def invoke_once(deinit self, ref value: Self.Payload) raises Self.Failure -> Self.Result:
        self.capture.counts[].used += 1
        self.capture.id += value.id
        if self.fail:
            raise ResourceOwnedFailure(self.capture^)
        return self.capture^

@fieldwise_init
struct OwnedIOBody(OnceThunk):
    var owner: ResourceOwner
    var fail: Bool
    var token: CancellationToken
    var cancel: Bool
    comptime Out = ResourceOwner
    comptime Error = ResourceOwnedFailure
    def call_once(deinit self) raises Self.Error -> Self.Out:
        self.owner.counts[].used += 1
        if self.cancel:
            self.token.cancel()
        if self.fail:
            raise ResourceOwnedFailure(self.owner^)
        return self.owner^


def main() raises:
    for acquire_fails in [False, True]:
        for use_fails in [False, True]:
            for release_fails in [False, True]:
                var counts = ArcPointer(ResourceLifeCounts(0, 0, 0, 0, 0))
                var scope = resource[ResourceOwnedFailure](OwnedScopeAcquire(ResourceOwner(1, counts.copy()), acquire_fails), OwnedScopeRelease(ResourceOwner(2, counts.copy()), release_fails))
                assert_equal(counts[].acquired, 0)
                var result = scope^.use(OwnedScopeUse(ResourceOwner(3, counts.copy()), use_fails))
                assert_equal(counts[].acquired, 1)
                assert_equal(counts[].used, 0 if acquire_fails else 1)
                assert_equal(counts[].released, 0 if acquire_fails else 1)
                _ = result^
                assert_equal(counts[].created, counts[].destroyed)

    var unopened = ArcPointer(ResourceLifeCounts(0, 0, 0, 0, 0))
    _ = resource[ResourceOwnedFailure](OwnedScopeAcquire(ResourceOwner(1, unopened.copy()), False), OwnedScopeRelease(ResourceOwner(2, unopened.copy()), False))
    assert_equal(unopened[].acquired, 0)
    assert_equal(unopened[].released, 0)
    assert_equal(unopened[].created, unopened[].destroyed)

    for body_fails in [False, True]:
        for finalizer_fails in [False, True]:
            for cancel in [False, True]:
                var counts = ArcPointer(ResourceLifeCounts(0, 0, 0, 0, 0))
                var token = CancellationToken()
                var program = guarantee(delay[ResourceOwnedFailure](OwnedIOBody(ResourceOwner(1, counts.copy()), body_fails, token.copy(), cancel)), delay[ResourceOwnedFailure](OwnedIOBody(ResourceOwner(2, counts.copy()), finalizer_fails, token.copy(), False)))
                var outcome = run_io(program^, token)
                assert_equal(counts[].used, 2)
                if body_fails or finalizer_fails:
                    assert_true(Bool(outcome))
                    var result = outcome.take()
                    assert_true(result.is_err())
                    var failure = result^._take_err()
                    assert_equal(len(failure.errors), Int(body_fails) + Int(finalizer_fails))
                    assert_equal(failure.canceled, cancel)
                    _ = failure^
                else:
                    assert_equal(Bool(outcome), not cancel)
                    _ = outcome^
                assert_equal(counts[].created, counts[].destroyed)
