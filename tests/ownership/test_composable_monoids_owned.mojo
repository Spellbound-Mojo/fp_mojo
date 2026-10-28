"""Move-only components are destroyed exactly once on success and failure."""
from fp.algebra import Monoid, ProductMonoid, OptionalMonoid, DictMonoid
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct MonoidLifetimeTrace(Copyable):
    var created: Int
    var destroyed: Int
    var calls: Int


struct MonoidOwnedValue(Movable):
    var value: Int
    var trace: ArcPointer[MonoidLifetimeTrace]
    def __init__(out self, value: Int, trace: ArcPointer[MonoidLifetimeTrace]):
        self.value = value
        self.trace = trace
        self.trace[].created += 1
    def __deinit__(deinit self):
        self.trace[].destroyed += 1


@fieldwise_init
struct MonoidCombineFailure(Movable):
    var value: Int


struct OwnedAddition(Monoid):
    comptime Value = MonoidOwnedValue
    comptime Error = MonoidCombineFailure
    @staticmethod
    def empty() raises Self.Error -> Self.Value:
        raise MonoidCombineFailure(-1)
    @staticmethod
    def combine(var left: Self.Value, var right: Self.Value) raises Self.Error -> Self.Value:
        left.trace[].calls += 1
        if left.value < 0:
            raise MonoidCombineFailure(left.value)
        left.value += right.value
        return left^


def main() raises:
    for failure in [False, True]:
        var trace = ArcPointer(MonoidLifetimeTrace(0, 0, 0))
        var caught = False
        var first = 0
        var second = 0
        try:
            var result = ProductMonoid[OwnedAddition, OwnedAddition].combine(
                (MonoidOwnedValue(-1 if failure else 1, trace), MonoidOwnedValue(2, trace)),
                (MonoidOwnedValue(3, trace), MonoidOwnedValue(4, trace)))
            first = result[0].value
            second = result[1].value
            _ = result^
        except error:
            comptime assert type_of(error) == MonoidCombineFailure
            caught = True
        assert_equal(caught, failure)
        if not failure:
            assert_equal(first, 4)
            assert_equal(second, 6)
        assert_equal(trace[].calls, 1 if failure else 2)
        assert_equal(trace[].destroyed, 4)
    var trace = ArcPointer(MonoidLifetimeTrace(0, 0, 0))
    var optional: Optional[MonoidOwnedValue]
    try:
        optional = OptionalMonoid[OwnedAddition].combine(
            Optional(MonoidOwnedValue(7, trace)), Optional[MonoidOwnedValue]())
    except:
        raise Error("absence must not invoke the combiner")
    assert_equal(trace[].calls, 0)
    _ = optional^
    assert_equal(trace[].destroyed, 1)
    for failure in [False, True]:
        var counts = ArcPointer(MonoidLifetimeTrace(0, 0, 0))
        var left = Dict[Int, MonoidOwnedValue]()
        left[1] = MonoidOwnedValue(-1 if failure else 2, counts)
        left[2] = MonoidOwnedValue(10, counts)
        var right = Dict[Int, MonoidOwnedValue]()
        right[1] = MonoidOwnedValue(3, counts)
        right[3] = MonoidOwnedValue(20, counts)
        var caught = False
        var saved = Optional[Dict[Int, MonoidOwnedValue]]()
        try:
            var merged = DictMonoid[Int, OwnedAddition].combine(left^, right^)
            saved = Optional(merged^)
        except error:
            comptime assert type_of(error) == MonoidCombineFailure
            caught = True
        assert_equal(caught, failure)
        if saved:
            var merged = saved.take()
            assert_equal(merged[1].value, 5)
            assert_equal(len(merged), 3)
        assert_equal(counts[].calls, 1)
        assert_equal(counts[].destroyed, counts[].created)
