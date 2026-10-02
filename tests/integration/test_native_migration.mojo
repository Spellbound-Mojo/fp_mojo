"""Native identity and client semantics survive the NI-1 spelling migration."""
from fp.data import Break, Continue, ControlFlow
from std.utils import Variant
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Resource(Movable):
    var value: Int
    var drops: ArcPointer[Int]

    def __deinit__(deinit self):
        self.drops[] += 1


def views[a: ImmOrigin, b: ImmOrigin](
    left: Span[Int, a], right: Span[Int, b]
) raises:
    comptime native = TypeList.of[Trait=AnyType, Span[Int, a], Span[Int, b], Resource]()
    comptime assert native[0] == type_of(left)
    comptime assert native[1] == type_of(right)
    comptime assert native[2] == Resource
    assert_equal(left[0] + right[0], 9)


def main() raises:
    # ControlFlow is a Choice: its storage is the native Variant of its constructors.
    comptime assert ControlFlow[Int, String].Layer.Subject == Variant[Break[Int], Continue[String]]
    var left: List[Int] = [4]
    var right: List[Int] = [5]
    views(Span(left), Span(right))
    var drops = ArcPointer(0)
    var calls = 0
    def transform(var value: Resource) {mut calls} -> Int:
        calls += 1
        return value.value
    # Canonical native Optional operations consume move-only payloads and skip
    # absent branches. No FP Maybe or transformation algorithm is involved.
    var present = Optional(Resource(7, drops))
    var result = present^.map(transform)
    comptime assert type_of(result) == Optional[Int]
    assert_equal(result.take(), 7)
    assert_equal(drops[], 1)
    var absent = Optional[Resource](None)
    assert_true(not absent^.map(transform))
    assert_equal(calls, 1)
    def next_value(var value: Int) -> Optional[Int]:
        return Optional(value + 1)
    var another = Optional(8)
    var chained = another^.and_then(next_value)
    assert_equal(chained.take(), 9)
