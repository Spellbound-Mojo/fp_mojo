"""Checked stored-error mapping; each family owns one two-arm operation."""
from .protocols import ErrorMapping
from fp.callables.protocols import UnaryContract
from fp.functions.composition import Identity


struct MapBothContract[I: ErrorMapping, V: Movable & Deinitable,
                       F: UnaryContract & Movable & Deinitable,
                       G: UnaryContract & Movable & Deinitable,
                       Target: ErrorMapping = I.DefaultErrorTarget[F.Out,G.Out]]:
    """Admission and exact metadata for mapping both selected outcome payloads.

    Forward Compatible or all five component predicates in generic wrappers.
    The source dictionary admits the destination policy, which owns subsequent
    operations. Native callback errors stay separate from stored failures.

    Parameters:
        I: The selected source family supporting stored-error mapping.
        V: The complete source carrier, including origins.
        F: The consuming success callback.
        G: The consuming stored-error callback.
        Target: The explicit destination or source's default candidate.
    """
    comptime SourceFailure = Self.I.Failure
    """The exact selected source stored-error type."""
    comptime Failure = Self.G.Out
    """The transformed stored-error type, including origins."""
    comptime Family = Self.Target
    """The destination family selected for fluent continuation."""
    comptime Out = Self.I.Bimapped[Self.Target,Self.V,Self.F,Self.G]
    """The exact carrier produced by the source primitive."""
    comptime Error = Self.I.BimapError[Self.Target,Self.V,Self.F,Self.G]
    """The exact construction error; deferred run errors stay in Out."""
    comptime SourceCompatible = Self.I.ErrorCarrierCompatible[Self.V]
    """The source belongs to the selected stored-error channel."""
    comptime InputCompatible = (Self.F.Arg == Self.I.Element[Self.V] and Self.G.Arg == Self.I.Failure) if Self.SourceCompatible else False
    """Both callback inputs match the selected payloads and origins."""
    comptime TargetCompatible = Self.Target.Failure == Self.G.Out
    """The destination selects exactly the transformed stored error."""
    comptime OperationCompatible = Self.I.BimapCompatible[Self.Target,Self.V,Self.F,Self.G]
    """The source admits this operation and destination policy."""
    comptime OutputCompatible = (
        Self.Target.ErrorCarrierCompatible[Self.Out] and Self.Target.Element[Self.Out] == Self.F.Out
    ) if Self.SourceCompatible and Self.InputCompatible and Self.TargetCompatible and Self.OperationCompatible else False
    """The admitted output belongs to Target with the exact success payload."""
    comptime Compatible = Self.SourceCompatible and Self.InputCompatible and Self.TargetCompatible and Self.OutputCompatible and Self.OperationCompatible
    """Complete checked admission, including both channel origins."""


comptime MapErrContract[I: ErrorMapping, V: Movable & Deinitable,
                       G: UnaryContract & Movable & Deinitable,
                       Target: ErrorMapping = I.DefaultErrorTarget[I.Element[V],G.Out]] = MapBothContract[I,V,Identity[I.Element[V]],G,Target]
"""Map the selected stored error, retaining the exact success type and origins.

Forward Compatible and project Family, Out and Error in generic wrappers.
The existing consuming Identity callback preserves successes through the same
family two-arm primitive; no second mapping traversal or execution owner exists.

Parameters:
    I: The selected source family supporting stored-error mapping.
    V: The complete source carrier, including origins.
    G: The consuming stored-error callback.
    Target: The explicit destination or source's default candidate.
"""


@always_inline
def _map_both[I: ErrorMapping, V: Movable & Deinitable,
              F: UnaryContract & Movable & Deinitable,
              G: UnaryContract & Movable & Deinitable,
              Target: ErrorMapping = I.DefaultErrorTarget[F.Out,G.Out]](
    var on_ok: F, var on_err: G, var source: V
) raises MapBothContract[I,V,F,G,Target].Error -> MapBothContract[I,V,F,G,Target].Out where MapBothContract[I,V,F,G,Target].Compatible:
    return I.bimap[Target](on_ok^,on_err^,source^)


@always_inline
def _map_err[I: ErrorMapping, V: Movable & Deinitable,
             G: UnaryContract & Movable & Deinitable,
             Target: ErrorMapping = I.DefaultErrorTarget[I.Element[V],G.Out]](
    var on_err: G, var source: V
) raises MapErrContract[I,V,G,Target].Error -> MapErrContract[I,V,G,Target].Out where MapErrContract[I,V,G,Target].Compatible:
    return _map_both[I,V,Identity[I.Element[V]],G,Target](Identity[I.Element[V]](),on_err^,source^)
