from fp.iteration import iterated
from test_iter_inferred_traversal_owned import IterOwner, owners
from std.memory import ArcPointer
from std.testing import assert_equal


def keep(var value: IterOwner) -> Optional[IterOwner]: return Optional(value^)
def fail(var value: IterOwner) raises IterOwner -> Optional[Int]: raise value^


def main() raises:
    var keep_pointer: def(var IterOwner) thin -> Optional[IterOwner] = keep
    var inputs = ArcPointer(0)
    var values = iterated(owners(inputs)).traverse(keep_pointer)
    assert_equal(values.value()[2].id, 2)
    assert_equal(inputs[], 0)
    _ = values^
    assert_equal(inputs[], 3)
    assert_equal(Bool(iterated(owners(inputs)).traverse_void(keep_pointer)), True)
    assert_equal(inputs[], 6)
    var fail_pointer: def(var IterOwner) raises IterOwner thin -> Optional[Int] = fail
    for discard in [False, True]:
        var drops = ArcPointer(0)
        var caught = False
        try:
            if discard: _ = iterated(owners(drops)).traverse_void(fail_pointer)
            else: _ = iterated(owners(drops)).traverse(fail_pointer)
        except failure:
            comptime assert type_of(failure) == IterOwner
            assert_equal(drops[], 2)
            caught = failure.id == 0
        assert_equal(caught, True)
        assert_equal(drops[], 3)
