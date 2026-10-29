"""Collection and discard retain unique ownership and independent origins."""
from fp.functions import kleisli
from fp.iteration import iterated
from fp.algebra import OptionalFamily, ResultFamily
from fp.data import Result, Err
from test_iter_inferred_post_traversal_owned import Token, values
from std.memory import ArcPointer
from std.testing import assert_equal, assert_false


def origins(owner: List[Int], other: List[Int]) raises:
    var view = Span(owner)
    var error = Span(other)
    comptime View = type_of(view)
    comptime Failure = type_of(error)
    def keep(var value: View) -> Optional[View]: return Optional(value)
    var chain = kleisli[OptionalFamily](keep)
    var collected = iterated(List[View]([view])).traverse(chain)
    assert_equal(Pointer(to=collected.value()[0][0]) == Pointer(to=owner[0]), True)
    _ = iterated(List[View]([view])).traverse_void(chain)
    def fail(var value: View) {error} -> Result[View, Failure]: return Err(error)
    var failing = kleisli[ResultFamily[Failure]](fail)
    var failure = iterated(List[View]([view])).traverse(failing)
    var void_failure = iterated(List[View]([view])).traverse_void(failing)
    var stored = failure^.swap().to_optional()
    var void_stored = void_failure^.swap().to_optional()
    assert_equal(Pointer(to=stored.value()[0]) == Pointer(to=other[0]), True)
    assert_equal(Pointer(to=void_stored.value()[0]) == Pointer(to=other[0]), True)


def main() raises:
    var drops = ArcPointer(0)
    var capture = Token(99, drops)
    def keep(var value: Token) {var capture^} -> Optional[Token]:
        value.id += capture.id
        return Optional(value^)
    var chain = kleisli[OptionalFamily](keep^)
    var collected = iterated(values(drops)).traverse(chain)
    assert_equal(drops[], 0)
    assert_equal(len(collected.value()), 3)
    assert_equal(collected.value()[0].id, 99)
    _ = collected^
    assert_equal(drops[], 3)
    _ = iterated(values(drops)).traverse_void(chain)
    assert_equal(drops[], 6)
    _ = chain.call(Token(4, drops))
    assert_equal(drops[], 7)
    _ = chain^
    assert_equal(drops[], 8)
    def reject(var value: Token) -> Optional[Token]:
        if value.id == 1: return None
        return Optional(value^)
    var rejecting = kleisli[OptionalFamily](reject)
    assert_false(Bool(iterated(values(drops)).traverse(rejecting)))
    assert_equal(drops[], 11)
    assert_false(Bool(iterated(values(drops)).traverse_void(rejecting)))
    assert_equal(drops[], 14)
    origins([3], [7])
