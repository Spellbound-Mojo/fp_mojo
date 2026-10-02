"""Matching an Optional borrows its value: nothing is copied or destroyed early."""
import fp
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct OptionalCleanupResource(Movable):
    var destroyed: ArcPointer[Int]
    var value: Int
    def __deinit__(deinit self):
        self.destroyed[] += 1


def native(var value: Optional[OptionalCleanupResource]) -> Int:
    if value:
        var item = value.take()
        return item.value
    return -1


def counted(calls: ArcPointer[Int], value: Int) -> Int:
    calls[] += 1
    return value


def run(destroyed: ArcPointer[Int], present: Bool, use_native: Bool) -> Int:
    var value = Optional[OptionalCleanupResource]()
    if present:
        value = Optional(OptionalCleanupResource(destroyed, 42))
    if use_native:
        return native(value^)
    var calls = ArcPointer(0)
    var observed = fp.match(value,
        lambda (item: OptionalCleanupResource, c: ArcPointer[Int]) -> Int: counted(c, item.value),
        lambda (n: NoneType, c: ArcPointer[Int]) -> Int: -1,
        context=calls)
    debug_assert[assert_mode="safe"](destroyed[] == 0)
    debug_assert[assert_mode="safe"](calls[] == Int(present))
    _ = value^
    return observed


def main() raises:
    for present in range(2):
        var native_destroyed = ArcPointer(0)
        var matched_destroyed = ArcPointer(0)
        assert_equal(run(matched_destroyed, Bool(present), False), run(native_destroyed, Bool(present), True))
        assert_equal(matched_destroyed[], native_destroyed[])
        assert_equal(matched_destroyed[], present)
