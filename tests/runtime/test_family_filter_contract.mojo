"""Generic family selection preserves admission, custom errors and deferred timing."""
from fp.algebra import Filterable, FilterContract, ListFamily, filter, filter_not
from fp.callables import BorrowCallContract, BorrowOnceCallable, mut_ref
from fp.functions import piped
from test_family_filter_mutable import EveryOther
from algebra_support.filtering import ContainerDeferredFamily
from test_context_selection_contracts import FailingFilter, PredicateFault
from std.testing import assert_equal


def accepted[I: Filterable, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var callback: C, var value: V) raises FilterContract[I, V, C].Error -> FilterContract[I, V, C].Out where FilterContract[I, V, C].Compatible:
    return filter[I](value^, callback^)


def rejected[I: Filterable, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](var callback: C, var value: V) raises FilterContract[I, V, C, True].Error -> FilterContract[I, V, C, True].Out where FilterContract[I, V, C, True].Compatible:
    return filter_not[I](value^, callback^)


struct Once(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Bool
    def __init__(out self): pass
    def invoke_once(deinit self, ref value: Int) -> Bool: return True


def main() raises:
    comptime assert not FilterContract[ListFamily, List[Int], Once].ReceiverCompatible
    comptime assert not FilterContract[ListFamily, List[Int], Once, True].Compatible
    var predicate = EveryOther(0)
    var input: List[Int] = [0, 1, 2, 3]
    assert_equal(accepted[ListFamily](mut_ref(predicate), input^), [1, 3])
    var inverse: List[Int] = [0, 1, 2, 3]
    assert_equal(rejected[ListFamily](mut_ref(predicate), inverse^), [0, 2])
    assert_equal(predicate.calls, 8)
    var delayed: List[Int] = [4, 5, 6, 7]
    var pending = piped(delayed^).filter_not[ContainerDeferredFamily](mut_ref(predicate)).get()
    assert_equal(predicate.calls, 8)
    assert_equal(pending^.run(), [4, 6])
    assert_equal(predicate.calls, 12)
    var code = 0
    var faulty: List[Int] = [0, 1]
    try:
        _ = accepted[FailingFilter](mut_ref(predicate), faulty^)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 733)
    assert_equal(predicate.calls, 12)
    var saw_callback_error = False
    var other: List[Int] = [0, 1]
    try:
        _ = rejected[PredicateFault](EveryOther(0), other^)
    except error:
        comptime assert type_of(error) == FilterContract[PredicateFault, List[Int], EveryOther, True].Predicate
        saw_callback_error = True
    assert_equal(saw_callback_error, True)
