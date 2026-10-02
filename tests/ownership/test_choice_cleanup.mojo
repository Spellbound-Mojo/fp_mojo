"""A Choice owns its constructor: one destruction, explicit copies, moves without copies."""
import fp
from fp.adt import Data, Cases, Choice, Value
from std.memory import ArcPointer
from std.testing import assert_equal


struct ChoiceCleanupResource(Copyable):
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]

    def __init__(out self, copies: ArcPointer[Int], drops: ArcPointer[Int]):
        self.copies = copies
        self.drops = drops

    def __init__(out self, *, copy: Self):
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1

    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct ChoiceCleanupEmpty(Copyable):
    pass


struct ChoiceCleanupData(Data):
    comptime Layer[R: Value] = Cases[ChoiceCleanupResource, ChoiceCleanupEmpty]


comptime Held = Choice[ChoiceCleanupData]


def held(value: Held) -> Int:
    return fp.match(value, lambda (r: ChoiceCleanupResource) -> Int: 1, lambda (e: ChoiceCleanupEmpty) -> Int: 0)


def main() raises:
    var copies = ArcPointer(0)
    var drops = ArcPointer(0)
    var value: Held = ChoiceCleanupResource(copies, drops)
    # Matching borrows: nothing is copied or destroyed.
    assert_equal(held(value), 1)
    assert_equal(copies[], 0)
    assert_equal(drops[], 0)
    # Copying is explicit and copies the constructor once.
    var copied = value.copy()
    assert_equal(copies[], 1)
    # Replacing a value destroys the constructor it held.
    copied = ChoiceCleanupEmpty()
    assert_equal(drops[], 1)
    assert_equal(held(copied), 0)
    # Moving the constructor out neither copies nor destroys it.
    var resource = value^.unwrap[ChoiceCleanupResource]()
    assert_equal(copies[], 1)
    assert_equal(drops[], 1)
    _ = resource^
    assert_equal(drops[], 2)
