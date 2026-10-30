"""Family filtering retains mutable state through ordinary callback syntax."""
from fp.callables import BorrowCallable, BorrowMutableCallable, mut_ref
from fp.functions import pipeline, piped
from fp.algebra import filter, filter_not, ListFamily, OptionalFamily
from std.testing import assert_equal

@fieldwise_init
struct EveryOther(BorrowCallable, BorrowMutableCallable):
    comptime Payload = Int
    comptime Result = Bool
    var calls: Int
    def invoke(self, ref value: Int) -> Bool: return False
    def invoke_mut(mut self, ref value: Int) -> Bool:
        self.calls += 1
        return self.calls % 2 == 0

def ordinary_forms() raises:
    var predicate = EveryOther(0)
    assert_equal(pipeline[Int]([0, 1, 2, 3]).filter(mut_ref(predicate)).get(), [1, 3])
    assert_equal(predicate.calls, 4)
    assert_equal(pipeline[Int]([0, 1, 2, 3]).filter_not(mut_ref(predicate)).get(), [0, 2])
    assert_equal(predicate.calls, 8)
    var input: List[Int] = [0, 1, 2, 3]
    assert_equal(piped(input^).filter(mut_ref(predicate)).get(), [1, 3])
    var other: List[Int] = [0, 1, 2, 3]
    assert_equal(piped(other^).filter_not(mut_ref(predicate)).get(), [0, 2])
    assert_equal(predicate.calls, 16)
    var free: List[Int] = [0, 1, 2, 3]
    assert_equal(filter[ListFamily](free^, mut_ref(predicate)), [1, 3])
    var inverse: List[Int] = [0, 1, 2, 3]
    assert_equal(filter_not[ListFamily](inverse^, mut_ref(predicate)), [0, 2])
    assert_equal(predicate.calls, 24)
    assert_equal(pipeline(Optional(7)).filter(mut_ref(predicate)).get(), Optional[Int]())
    assert_equal(predicate.calls, 25)
    assert_equal(pipeline(Optional(7)).filter(mut_ref(predicate)).get(), Optional(7))
    assert_equal(predicate.calls, 26)


def main() raises:
    ordinary_forms()
    # Owned calls choose the mutable receiver even when a shared one exists.
    assert_equal(pipeline[Int]([0, 1, 2, 3]).filter(EveryOther(0)).get(), [1, 3])
    assert_equal(pipeline[Int]([0, 1, 2, 3]).filter_not(EveryOther(0)).get(), [0, 2])
    var callback = EveryOther(0)
    assert_equal(pipeline(List[Int]()).filter(mut_ref(callback)).get(), List[Int]())
    assert_equal(pipeline(Optional[Int]()).filter_not(mut_ref(callback)).get(), Optional[Int]())
    assert_equal(callback.calls, 0)
