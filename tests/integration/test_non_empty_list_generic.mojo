"""Non-empty families retain generic errors, borrowed payloads and deferred effects."""
from fp.data import NonEmptyList
from fp.algebra import NonEmptyListFamily, NonEmptyListSemigroup, map, traverse
from fp.effects import Reader, run
from fp.functions import piped
from std.testing import assert_equal


def nelg_map[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable,
             F: def(var A) raises X -> B](var values: NonEmptyList[A], ref f: F
) raises X -> NonEmptyList[B]:
    return map[NonEmptyListFamily, X=X](values^, f)

def nelg_same[o: ImmOrigin](var value: Span[Int, o]) raises String -> Span[Int, o]:
    return value

def nelg_borrows(values: List[Int]) raises:
    var view = Span(values)
    comptime View = type_of(view)
    var source = NonEmptyList(view)
    var mapped = nelg_map(source^, nelg_same[origin_of(values)])
    comptime assert type_of(mapped) == NonEmptyList[View]
    assert_equal(mapped.first()[1], 8)
    var joined = NonEmptyListSemigroup[View].combine(mapped^, NonEmptyList(view))
    assert_equal(joined^.into_list()[1][0], 7)
    var projected = piped(NonEmptyList(view)).map[NonEmptyListFamily](nelg_same[origin_of(values)]).get()
    assert_equal(projected.first()[0], 7)

def nelg_produce(var value: Int) -> Reader[Int].Pure[Int]:
    return Reader[Int].pure(value)

def main() raises:
    nelg_borrows(List[Int]([7, 8]))
    var mutable_values = List[Int]([1, 2])
    var mutable_view = Span(mutable_values)
    var singleton = NonEmptyList(mutable_view)
    singleton.first()[0] = 7
    _ = singleton^
    assert_equal(mutable_values[0], 7)
    var effect = traverse[Reader[Int], NonEmptyListFamily](NonEmptyList(1, List[Int]([2])), nelg_produce)
    var result = run[Reader[Int]](effect^, 42)
    assert_equal(result^.into_list(), [1, 2])
    print("non-empty list generic: ok")
