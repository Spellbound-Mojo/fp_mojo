"""Derived traversal policies over the canonical family traversal and loop."""
from fp.algebra._admission import _BindCompatible
from std.builtin.rebind import downcast, rebind, rebind_var
from fp.callables.protocols import Unary, UnaryContract, BorrowCallContract
from fp.callables._transforms import _Fill
from fp._internal.errors import _CommonError, _ErrorCompatible, _propagate_error
from .protocols import Applicative, Traversable, Monad, FunctorFilter, _Accumulate, _map_as, _traverse_as
from ._sequencing import _EffectRetain
from ._derived import flatten
from .filtering import compact
from fp.callables._identity import Identity


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
    try:
        return G._loop[V, F, _Discard[G.Element[F.Out]]](function^, source^)
    except error:
        comptime assert _ErrorCompatible[Raised, type_of(error)]
        _propagate_error[Raised](error^)


@fieldwise_init
struct _FlattenAfter[S: Monad, V: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Remove one source-family layer after traversal, inside the target effect."""
    comptime Arg = Self.V
    comptime Out = Self.S.Bound[Self.V, Identity[Self.S.Element[Self.V]]]
    comptime Error = Self.S.BindError[Self.V, Identity[Self.S.Element[Self.V]]]
    def call(self, var value: Self.V) raises Self.Error -> Self.Out:
        comptime assert _BindCompatible[Self.S, Self.V, Identity[Self.S.Element[Self.V]]]
        return flatten[Self.S](value^)


@fieldwise_init
struct _CompactAfter[S: FunctorFilter, V: Movable & Deinitable](Unary, Copyable, Defaultable):
    """Keep present payloads after traversal using the source's filtering owner."""
    comptime Arg = Self.V
    comptime Out = Self.S.MapFiltered[Self.V, Identity[Self.S.Element[Self.V]]]
    comptime Error = Self.S.MapFilterError[Self.V, Identity[Self.S.Element[Self.V]]]
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
    comptime Out = Self.G.Mapped[Self.V, Self.Discard]
    comptime Error = Self.G.MapError[Self.V, Self.Discard]
    def call(self, var value: Self.V) raises Self.Error -> Self.Out:
        return Self.G.map(Self.Discard(None), value^)


# Preserve the traversal's private spelling; sequencing and traversal share
# the same borrowing, retention and receiver-mode implementation.
comptime _TraverseTap[T: Movable & Deinitable, G: Applicative, C: BorrowCallContract & Movable & Deinitable, selected: Bool = False] = _EffectRetain[T, G, C, selected]
