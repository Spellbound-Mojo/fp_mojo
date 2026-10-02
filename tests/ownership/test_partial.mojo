"""Partial ownership: one copy per bound value at construction and per call,
borrowed remaining arguments, unchanged stored values, and native cleanup."""
from fp.functions import partial
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Tracked(Copyable):
    var values: List[Int]
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]

    def __init__(out self, *, copy: Self):
        self.values = copy.values.copy()
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1

    def __deinit__(deinit self):
        self.drops[] += 1


def total(values: List[Int]) -> Int:
    var sum = 0
    for v in values:
        sum += v
    return sum


def read_both(bound: Tracked, extra: Tracked) -> Int:
    return total(bound.values) * 100 + total(extra.values)


def consume(var bound: Tracked, extra: Tracked) -> Int:
    # Mutates only this call's copy.
    bound.values.append(1000)
    return total(bound.values) + total(extra.values)


@fieldwise_init
struct PartialFailure(Movable):
    var code: Int


def fail(var bound: Tracked, code: Int) raises PartialFailure -> Int:
    if code < 0:
        raise PartialFailure(total(bound.values))
    return code


def bump(handle: ArcPointer[Int], step: Int) -> Int:
    handle[] += step
    return handle[]


def main() raises:
    var copies = ArcPointer(0)
    var drops = ArcPointer(0)
    var original = Tracked([1, 2], copies, drops)
    var extra = Tracked([5], copies, drops)

    # Construction copies each bound value once; the original stays independent.
    var reader = partial(read_both, original)
    assert_equal(copies[], 1)
    original.values.append(100)
    # Each call copies each bound value once and drops it afterwards; remaining
    # arguments are borrowed, never copied or moved.
    assert_equal(reader(extra), 305)
    assert_equal(reader(extra), 305)
    assert_equal(copies[], 3)
    assert_equal(drops[], 2)
    assert_equal(total(extra.values), 5)

    # An owning target mutates its per-call copy; the stored value is unchanged.
    var owner = partial(consume, original)
    assert_equal(copies[], 4)
    assert_equal(owner(extra), 1108)
    assert_equal(owner(extra), 1108)
    assert_equal(copies[], 6)
    assert_equal(drops[], 4)
    assert_equal(total(original.values), 103)

    # Failure drops the per-call copy; the stored value survives for later calls.
    var failing = partial(fail, original)
    assert_equal(copies[], 7)
    var caught = False
    try:
        _ = failing(-1)
    except error:
        caught = True
        assert_equal(error.code, 103)
    assert_true(caught)
    assert_equal(copies[], 8)
    assert_equal(drops[], 5)
    var recovered: Int
    try:
        recovered = failing(7)
    except error:
        recovered = -error.code
    assert_equal(recovered, 7)
    assert_equal(copies[], 9)
    assert_equal(drops[], 6)

    # Copying a partial copies its stored values once; each copy is independent.
    var copied = reader.copy()
    assert_equal(copies[], 10)
    assert_equal(copied(extra), 305)
    assert_equal(copies[], 11)
    assert_equal(drops[], 7)

    # Dropping a partial drops its stored value.
    _ = copied^
    assert_equal(drops[], 8)
    _ = reader^
    _ = owner^
    _ = failing^
    assert_equal(drops[], 11)
    _ = original^
    _ = extra^
    assert_equal(drops[], 13)
    assert_equal(copies[], 11)

    # A copied handle shares its referent, as native copy semantics define.
    var handle = ArcPointer(5)
    var step = partial(bump, handle)
    assert_equal(step(1), 6)
    assert_equal(step(2), 8)
    assert_equal(handle[], 8)

    # Heap-backed remaining arguments arrive intact (Mojo 1.1 owned-pack
    # conversion would hand the target a dangling value).
    var reading = partial(read_both, Tracked([7], copies, drops))
    var listed = Tracked([10, 20, 30], copies, drops)
    assert_equal(reading(listed), 760)
    assert_equal(reading(listed), 760)
    print("partial ownership: ok")
