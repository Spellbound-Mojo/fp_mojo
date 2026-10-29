"""Derived traversal policies over the canonical family traversal and loop."""
from ._primitive_contracts import BindContract, MapContract, FilterMapContract
from .contracts import TraverseContract
from fp.algebra._admission import _BindCompatible
from std.builtin.rebind import downcast, rebind, rebind_var
from fp.callables.protocols import Unary, UnaryContract, BorrowCallContract
from fp.callables._transforms import _Fill
from fp._internal.errors import _CommonError, _CommonErrorCompatible, _ErrorCompatible
from .protocols import Applicative, Traversable, Monad, FunctorFilter, _Accumulate, _map_as, _traverse_as, _loop_as
from ._sequencing import _EffectRetain
from ._derived import flatten
from .filtering import compact
from fp.callables._identity import Identity
from fp.callables.invoke import _OnceUnaryAvailable
from fp.iteration._advance import _OwnedElement


struct _Discard[T: Movable & Deinitable](_Accumulate):
    """Run effects without retaining their successful payloads."""
    comptime Acc = NoneType
    comptime Item = Self.T
    @staticmethod
    def start() -> NoneType: return None
    @staticmethod
    def live(ref acc: NoneType) -> Bool: return True
    @staticmethod
    def combine(var acc: NoneType, var item: Self.T) -> NoneType: return None


def _traverse_void[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, G: Applicative,
                   Raised: Movable & Deinitable = G._LoopError[V, F, _Discard[G.Element[F.Out]]]](
    var function: F, var source: V
) raises Raised -> G._Looped[V, F, _Discard[G.Element[F.Out]]]:
    return _loop_as[Raised, G, V, F, _Discard[G.Element[F.Out]]](function^, source^)


@fieldwise_init
struct _FlattenAfter[S: Monad, V: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Remove one source-family layer after traversal, inside the target effect."""
    comptime Arg = Self.V
    comptime _Operation = BindContract[Self.S, Self.V, Identity[Self.S.Element[Self.V]]]
    comptime Out = Self._Operation.Out
    comptime Error = Self._Operation.Error
    def call(self, var value: Self.V) raises Self.Error -> Self.Out:
        comptime assert _BindCompatible[Self.S, Self.V, Identity[Self.S.Element[Self.V]]]
        return flatten[Self.S](value^)


@fieldwise_init
struct _CompactAfter[S: FunctorFilter, V: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Keep present payloads after traversal using the source's filtering owner."""
    comptime Arg = Self.V
    comptime _Operation = FilterMapContract[Self.S, Self.V, Identity[Self.S.Element[Self.V]]]
    comptime Out = Self._Operation.Out
    comptime Error = Self._Operation.Error
    def call(self, var value: Self.V) raises Self.Error -> Self.Out:
        return compact[Self.S](value^)


def _traverse_then[S: Traversable, G: Applicative, V: Movable & Deinitable,
                   F: UnaryContract & Movable & Deinitable, H: Unary,
                   Raised: Movable & Deinitable](
    var function: F, var source: V, var finish: H
) raises Raised -> G.Mapped[S.Traversed[G, V, F], H]:
    # Postprocessing belongs inside G: failures skip it and deferred targets
    # defer it. No assumptions about the target's representation or timing.
    var produced = _traverse_as[S, G, V, F, Raised](function^, source^)
    comptime assert _ErrorCompatible[Raised, G.MapError[S.Traversed[G, V, F], H]]
    return _map_as[Raised, G](finish^, produced^)


@fieldwise_init
struct _EffectVoid[G: Applicative, V: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Discard one effect's payload; source Result errors stay with traversal."""
    comptime Arg = Self.V
    comptime Discard = _Fill[Self.G.Element[Self.V], NoneType]
    comptime _Operation = MapContract[Self.G, Self.V, Self.Discard]
    comptime Out = Self._Operation.Out
    comptime Error = Self._Operation.Error
    def call(self, var value: Self.V) raises Self.Error -> Self.Out:
        return Self.G.map(Self.Discard(None), value^)


# Preserve the traversal's private spelling; sequencing and traversal share
# the same borrowing, retention and receiver-mode implementation.
comptime _TraverseTap[T: Movable & Deinitable, G: Applicative, C: BorrowCallContract & Movable & Deinitable, selected: Bool = False] = _EffectRetain[T, G, C, selected]


struct _FinishedTraversalContract[S: Traversable, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, H: Unary, shape: Bool = True]:
    """Shared admission for traversal followed by a map inside its target."""
    comptime _Traverse = TraverseContract[Self.S, Self.G, Self.V, Self.F]
    comptime _Finish = MapContract[Self.G, Self._Traverse.Out, Self.H]
    comptime InputCompatible = Self._Traverse.InputCompatible
    comptime SourceCompatible = Self._Traverse.SourceCompatible
    comptime TargetCompatible = Self._Traverse.TargetCompatible
    comptime CarrierCompatible = Self._Traverse.CarrierCompatible
    comptime ShapeCompatible = Self.shape
    comptime FinishCompatible = Self._Finish.FamilyCompatible
    comptime FamilyCompatible = Self._Traverse.FamilyCompatible and Self.ShapeCompatible and Self.FinishCompatible
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible
    comptime ReceiverCompatible = _OnceUnaryAvailable[Self.F]
    comptime FinishInvocationCompatible = Self._Finish.InvocationCompatible
    comptime ConstructionCompatible = _CommonErrorCompatible[Self._Traverse.Error, Self._Finish.Error]
    comptime InvocationCompatible = Self.Compatible and Self.ReceiverCompatible and Self.FinishInvocationCompatible and Self.ConstructionCompatible
    comptime Family = Self.G
    comptime Out = Self._Finish.Out
    comptime Error = _CommonError[Self._Traverse.Error, Self._Finish.Error]


comptime TraverseFilterContract[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _FinishedTraversalContract[S, G, V, F, _CompactAfter[S, G.Element[S.Traversed[G, V, F]]], G.Element[F.Out] == Optional[_OwnedElement[G.Element[F.Out]]]]
"""Admission and exact result of traversal collecting present Optional payloads.

Generic helpers forward InvocationCompatible and project Out, Error and Family.
Compatible preserves the selected traverse_filter/sequence_filter requirements;
InvocationCompatible additionally checks the callback receiver, finishing map
and construction-error compatibility. Source and target families own execution,
including source-specific callback timing and deferred errors.

Parameters:
    S: The source family, supporting traversal and compaction.
    G: The target Applicative family.
    V: The complete consumed source carrier, including origins.
    F: The library callback returning Optional payloads inside G.
"""


comptime FlatTraverseContract[S: Traversable & Monad, G: Applicative, V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _FinishedTraversalContract[S, G, V, F, _FlattenAfter[S, G.Element[S.Traversed[G, V, F]]], S.CarrierCompatible[G.Element[F.Out]] and S.BindCompatible[G.Element[S.Traversed[G, V, F]], Identity[S.Element[G.Element[S.Traversed[G, V, F]]]]]]
"""Admission and exact result of traversal flattening one source-family layer.

Generic helpers forward InvocationCompatible and project Out, Error and Family.
Compatible preserves the selected flat_traverse/flat_sequence requirements;
InvocationCompatible additionally checks the callback receiver, finishing map
and construction-error compatibility. The source's bind and target's map retain
their existing ownership, branching and evaluation policies.

Parameters:
    S: The source family, supporting traversal and binding.
    G: The target Applicative family.
    V: The complete consumed source carrier, including origins.
    F: The library callback returning source-family carriers inside G.
"""


struct FilterEffectContract[S: Traversable & FunctorFilter, G: Applicative, V: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable]:
    """Admission and exact result of filtering through a borrowing effect.

    Generic helpers forward InvocationCompatible and project Out and Error.
    Compatible preserves selected filter_effect admission. The stronger
    invocation predicate also checks the observer receiver, retention map,
    compaction map and compatibility of their construction errors.
    Existing traversal, retention and compaction owners retain all execution.

    Parameters:
        S: The source family, supporting traversal and compaction.
        G: The target Applicative family, including branching and deferral.
        V: The complete consumed source carrier, including origins.
        C: The borrowing predicate producing Bool inside a carrier in G.
    """
    comptime _Retained = _EffectRetain[Self.S.Element[Self.V], Self.G, Self.C, True]
    comptime _Traverse = TraverseContract[Self.S, Self.G, Self.V, Self._Retained]
    comptime _Finish = _CompactAfter[Self.S, Self.G.Element[Self._Traverse.Out]]
    comptime _Post = _FinishedTraversalContract[Self.S, Self.G, Self.V, Self._Retained, Self._Finish]
    comptime InputCompatible = Self._Retained.InputCompatible
    """The predicate borrows the exact source element, including origins."""
    comptime CarrierCompatible = Self.G.CarrierCompatible[Self.C.Result]
    """The predicate produces a carrier of the target family."""
    comptime PredicateCompatible = Self.G.Element[Self.C.Result] == Bool
    """The predicate's target-family payload is Bool."""
    comptime SourceCompatible = Self._Traverse.SourceCompatible
    """The source admits traversal with the retaining continuation."""
    comptime TargetCompatible = Self._Traverse.TargetCompatible
    """The source's selected target operations admit that continuation."""
    comptime RetainedShapeCompatible = Self.G.Element[Self._Retained.Out] == Optional[Self.S.Element[Self.V]]
    """The retention map produces exact Optional source elements."""
    comptime FinishCompatible = Self._Post.FinishCompatible
    """The target admits mapping source compaction over the traversal."""
    comptime FamilyCompatible = Self.CarrierCompatible and Self.PredicateCompatible and Self.SourceCompatible and Self.TargetCompatible and Self.RetainedShapeCompatible and Self.FinishCompatible
    """Existing selected filtering admission without input equality."""
    comptime Compatible = Self.InputCompatible and Self.FamilyCompatible
    """The complete existing selected filter_effect entry predicate."""
    comptime ReceiverCompatible = Self._Retained.ReceiverCompatible
    """The original predicate has an invocable receiver."""
    comptime RetentionCompatible = Self._Retained.InvocationCompatible and Self._Retained.Finish.InvocationCompatible
    """The shared retention kernel and target map admit the original value."""
    comptime ConstructionCompatible = Self._Post.ConstructionCompatible
    """Traversal and finishing construction errors have one native type."""
    comptime InvocationCompatible = Self.Compatible and Self.RetentionCompatible and Self._Post.FinishInvocationCompatible and Self.ConstructionCompatible
    """Checked admission for new generic helpers, including retention and finishing."""
    comptime Family = Self.G
    """The family selected for fluent continuation over Out."""
    comptime Out = Self._Post.Out
    """The source shape containing accepted elements inside the target effect."""
    comptime Error = Self._Post.Error
    """The exact construction error; deferred execution keeps its own errors."""
