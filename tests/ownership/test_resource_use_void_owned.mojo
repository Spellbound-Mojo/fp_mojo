"""Acquired owners, skipped captures and move-only errors are destroyed once."""
from test_resource_io_owned import ResourceLifeCounts, ResourceOwner, ResourceOwnedFailure, OwnedScopeAcquire, OwnedScopeRelease
from fp.effects import resource, lift_resource, CancellationToken
from fp.functions import pipeline
from std.memory import ArcPointer
from std.testing import assert_equal


def main() raises:
    comptime for effectful in range(2):
        for mode in range(5):
            var counts = ArcPointer(ResourceLifeCounts(0,0,0,0,0))
            var scope = resource[ResourceOwnedFailure](
                OwnedScopeAcquire(ResourceOwner(1,counts),mode == 1),
                OwnedScopeRelease(ResourceOwner(2,counts),mode == 2))
            comptime if effectful:
                var program = lift_resource(scope^).use_void()
                assert_equal(counts[].acquired,0)
                if mode == 3:
                    _ = program^
                else:
                    var token = CancellationToken()
                    if mode == 4: token.cancel()
                    var result = pipeline(program^).run_io(token)
                    if mode == 4: assert_equal(Bool(result),False)
                    _ = result^
            else:
                if mode >= 3:
                    _ = scope^
                else:
                    var result = scope^.use_void()
                    assert_equal(result.is_err(),mode == 1 or mode == 2)
                    _ = result^
            assert_equal(counts[].acquired,0 if mode >= 3 else 1)
            assert_equal(counts[].released,1 if mode == 0 or mode == 2 else 0)
            assert_equal(counts[].used,0)
            assert_equal(counts[].destroyed,counts[].created)
