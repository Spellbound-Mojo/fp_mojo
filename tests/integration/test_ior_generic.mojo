"""Ior retains generic native errors and immutable/mutable payload origins."""
from fp.data import Ior, Left, Right, Both
from fp.algebra import IorFamily, StringMonoid, ListMonoid, map, flat_map
from fp.functions import piped, Identity
from fp.algebra import Functor, Monad, Applicative, Traversable, ListFamily, traverse
from fp.callables import Unary, UnaryContract
from std.testing import assert_equal, assert_true

# A family parameter may override admission; preserve the public predicates.
def ig_family_map[I: Functor, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var f: F, var source: V
) raises I.MapError[V, F] -> I.Mapped[V, F] where I.Element[V] == F.Arg and I.MapCompatible[V, F]:
    return map[I](source^, f^)

def ig_family_bind[I: Monad, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var f: F, var source: V
) raises I.BindError[V, F] -> I.Bound[V, F] where I.Element[V] == F.Arg and I.BindCompatible[V, F]:
    return flat_map[I](source^, f^)

def ig_family_traverse[S: Traversable, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var f: F, var source: V
) raises S.TraverseError[G, V, F] -> S.Traversed[G, V, F] where S.Element[V] == F.Arg and S.TargetCompatible[G, V, F]:
    return traverse[S, G](source^, f^)

@fieldwise_init
struct IGNext(Unary, Copyable, Defaultable):
    comptime Arg = Int
    comptime Out = Ior[String, Int]
    comptime Error = Never
    def call(self, var value: Int) -> Self.Out: return Both(String("next"), value + 1)

@fieldwise_init
struct IGViewStep[o: ImmOrigin](Unary, Copyable):
    comptime Arg = Span[Int, Self.o]
    comptime Out = Ior[String, Span[Int, Self.o]]
    def call(self, var value: Self.Arg) -> Self.Out: return Both(String("view"), value)

def ig_map[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable,
           F: def(var A) raises X -> B](var source: Ior[String, A], ref f: F
) raises X -> Ior[String, B]:
    return map[IorFamily[StringMonoid], X=X](source^, f)

def ig_bind[A: Movable & Deinitable, B: Movable & Deinitable, X: Movable & Deinitable,
            F: def(var A) raises X -> Ior[String, B]](var source: Ior[String, A], ref f: F
) raises X -> Ior[String, B]:
    return flat_map[IorFamily[StringMonoid], X=X](source^, f)

def ig_identity[o: Origin](var value: Span[Int, o]) raises String -> Span[Int, o]: return value
def ig_next[o: Origin](var value: Span[Int, o]) raises String -> Ior[String, Span[Int, o]]:
    return Both(String("next"), value)

def ig_raise_view[o: ImmOrigin](var value: Span[Int, o]) raises Span[Int, o] -> Ior[String, Span[Int, o]]:
    if value[0] == 7: raise value
    return Right(value)

def ig_borrow(values: List[Int]) raises:
    var view = Span(values)
    comptime View = type_of(view)
    var traversed = ig_family_traverse[ListFamily, IorFamily[StringMonoid]](
        IGViewStep[origin_of(values)](), List[View]([view]))
    assert_equal(traversed[Both[String, List[View]]].right[0][0], 7)
    var value = Ior[String, View](Both(String("first"), view))
    var mapped = ig_map(value^, ig_identity[origin_of(values)])
    var bound = ig_bind(mapped^, ig_next[origin_of(values)])
    comptime assert type_of(bound) == Ior[String, View]
    assert_equal(bound[Both[String, View]].right[1], 8)
    assert_equal(bound[Both[String, View]].left, "firstnext")
    var issues = List[View]([view])
    var diagnostics = Ior[List[View], Int](Both(issues^, 4))
    def later(value: Int) -> Ior[List[View], Int]: return Right(value * 2)
    var kept = flat_map[IorFamily[ListMonoid[View]]](diagnostics^, later)
    assert_equal(kept[Both[List[View], Int]].left[0][0], 7)
    assert_equal(kept[Both[List[View], Int]].right, 8)
    var raised = False
    try:
        _ = ig_bind(Ior[String, View](Right(view)), ig_raise_view[origin_of(values)])
    except error:
        raised = True
        comptime assert type_of(error) == View
        assert_equal(error[1], 8)
    assert_true(raised)

def ig_fail(var value: Int) raises String -> Int:
    if value == 7: raise String("raised, not stored")
    return value

def main() raises:
    comptime I = IorFamily[StringMonoid]
    var forwarded = ig_family_map[I](Identity[Int](), Ior[String, Int](Both(String("first"), 3)))
    var bound = ig_family_bind[I](IGNext(), forwarded^)
    assert_equal(bound[Both[String, Int]].left, "firstnext")
    assert_equal(bound[Both[String, Int]].right, 4)
    var collected = ig_family_traverse[ListFamily, I](IGNext(), List[Int]([1, 2]))
    assert_equal(collected[Both[String, List[Int]]].left, "nextnext")
    assert_equal(collected[Both[String, List[Int]]].right, List[Int]([2, 3]))
    ig_borrow(List[Int]([7, 8]))
    var values = List[Int]([1, 2])
    var view = Span(values)
    comptime View = type_of(view)
    var source = Ior[String, View](Both(String("mutable"), view))
    source[Both[String, View]].right[0] = 9
    _ = source^
    assert_equal(values[0], 9)
    var raised = False
    try:
        _ = ig_map(Ior[String, Int](Both(String("stored"), 7)), ig_fail)
    except error:
        raised = True
        assert_equal(error, "raised, not stored")
    assert_true(raised)
    var skipped = piped(Ior[String, Int](Left(String("stored")))).map[IorFamily[StringMonoid]](ig_fail).get()
    assert_equal(skipped[Left[String]].value, "stored")
    print("ior generic: ok")
