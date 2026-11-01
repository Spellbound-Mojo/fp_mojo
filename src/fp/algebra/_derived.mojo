"""Operations derived from the primitive protocols; no new execution paths."""
from fp.algebra._admission import _BindCompatible, _CombineCompatible, _CollectCompatible
from fp.callables.protocols import BinaryContract
from fp.callables._identity import Identity
from fp.callables._transforms import _ValueThunk as _Value, _Pair, _KeepOperand, _Apply
from ._contracts import ApContract, ProductContract, ProductLeftContract, ProductRightContract, Map2Contract, _Function
from .protocols import Applicative, Monad, Traversable, _map2_lazy_as
from fp._internal.errors import _ErrorCompatible
from std.builtin.rebind import downcast
from .collections import _SourceFamily, _UnrecognizedCarrier
from .instances import _InferredApplicative


def _map2_as[V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
             //, I: Applicative, X: Movable & Deinitable](
    var f: F, var left: V, var right: W
) raises X -> I.Combined[V, F, _Value[W]]:
    comptime assert _CombineCompatible[I, V, F, _Value[W]]
    # Native carrier syntax knows the exact callback error. Keep the family's
    # public symbolic error spelling intact and admit that identity here.
    comptime assert _ErrorCompatible[X, I.CombineError[V, F, _Value[W]]]
    return _map2_lazy_as[X, I](f^, left^, _Value(right^))


comptime _Same[T: Movable & Deinitable] = Identity[T]


def map2[V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, //, I: Applicative = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Applicative) else _UnrecognizedCarrier, Applicative]](
    var f: F, var left: V, var right: W
) raises Map2Contract[I, V, W, F].Error -> Map2Contract[I, V, W, F].Out where Map2Contract[I, V, W, F].OperationCompatible:
    """Combine two carriers with `f`, where the right one is already computed.

    It is `map2_lazy` with a right operand that returns `right`.

    Parameters:
        V: The left carrier's type.
        W: The right carrier's type.
        F: The combiner's type: a library `Binary` value.
        I: The instance; defaults to the first carrier's family.

    Args:
        f: The combiner, consumed.
        left: The left carrier, consumed.
        right: The right carrier, consumed.

    Returns:
        The carrier of the combined payloads.

    Raises:
        The combiner's error.
    """
    return _map2_as[I, X=Map2Contract[I, V, W, F].Error](f^, left^, right^)


def ap[V: Movable & Deinitable, W: Movable & Deinitable, //, I: Applicative = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Applicative) else _UnrecognizedCarrier, Applicative]](var functions: V, var values: W
) raises ApContract[I, V, W].Error -> ApContract[I, V, W].Out where ApContract[I, V, W].OperationCompatible:
    """Apply the callbacks a carrier holds to the values another carrier holds.

    Parameters:
        V: The type of the carrier of callbacks, which are library `Unary` values.
        W: The type of the carrier of values.
        I: The instance; defaults to the first carrier's family.

    Args:
        functions: The carrier of callbacks, consumed.
        values: The carrier of values, consumed.

    Returns:
        The carrier of the results; for lists, every callback applied to every
        value in left-major order.

    Raises:
        The callbacks' error.
    """
    return map2[I](_Apply[_Function[I, V]](), functions^, values^)


def flatten[V: Movable & Deinitable, //, I: Monad = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Monad) else _UnrecognizedCarrier, Monad]](var nested: V
) raises I.BindError[V, _Same[I.Element[V]]] -> I.Bound[V, _Same[I.Element[V]]] where _BindCompatible[I, V, _Same[I.Element[V]]]:
    """Remove one level of the same context: `flat_map` with the identity.

    Parameters:
        V: The nested carrier's type, such as `Optional[Optional[A]]`.
        I: The instance; defaults to the first carrier's family.

    Args:
        nested: The nested carrier, consumed.

    Returns:
        The inner carrier, or the outer context when there is no payload.

    Raises:
        The instance's bind error; the identity callback itself raises nothing.
    """
    return I.flat_map(Identity[I.Element[V]](), nested^)


def sequence[V: Movable & Deinitable, //, G: Applicative = _InferredApplicative[downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable].Element[V]], S: Traversable = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Traversable) else _UnrecognizedCarrier, Traversable]](var source: V
) raises S.TraverseError[G, V, _Same[S.Element[V]]] -> S.Traversed[G, V, _Same[S.Element[V]]] where S.TargetCompatible[G, V, _Same[S.Element[V]]]:
    """Turn a source of `G` carriers into one `G` carrier of the source: `traverse` with the identity.

    Parameters:
        V: The source's type, such as `List[Optional[A]]`.
        G: The carriers' instance; defaults to the family of the source's elements.
        S: The source's instance; defaults to the source's family.

    Args:
        source: The source, consumed.

    Returns:
        `G`'s carrier of the payloads in source shape; it stops at the first
        failure.

    Raises:
        Any error `G` adds.
    """
    return S.traverse[G](Identity[S.Element[V]](), source^)


def product[V: Movable & Deinitable, W: Movable & Deinitable, //, I: Applicative = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Applicative) else _UnrecognizedCarrier, Applicative]](var left: V, var right: W
) raises ProductContract[I, V, W].Error -> ProductContract[I, V, W].Out where ProductContract[I, V, W].OperationCompatible:
    """Combine already computed operands into pairs through map2.

    Parameters:
        V: The left carrier type, including origins.
        W: The right carrier type, including origins.
        I: The Applicative family, which defines combination and errors; defaults to the first carrier's family.

    Args:
        left: The first carrier, consumed.
        right: The second carrier, consumed; already evaluated.

    Returns:
        The carrier of pairs. Lists form a Cartesian product in left-major order.

    Raises:
        The family's combination error, unchanged.
    """
    return map2[I](_Pair[I.Element[V], I.Element[W]](), left^, right^)


def product_l[V: Movable & Deinitable, W: Movable & Deinitable, //, I: Applicative = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Applicative) else _UnrecognizedCarrier, Applicative]](var left: V, var right: W
) raises ProductLeftContract[I, V, W].Error -> ProductLeftContract[I, V, W].Out where ProductLeftContract[I, V, W].Compatible:
    """Combine existing effects and keep the left payload on success.

    Arguments are constructed before this call. Deferred recipes still run
    later. Validation accumulates errors; List forms a left-major Cartesian
    product and retains one left payload for every successful pair.

    Parameters:
        V: The complete left carrier type, including origins.
        W: The complete right carrier type, including origins.
        I: The Applicative family owning combination and errors; defaults to the first carrier's family.

    Args:
        left: The first carrier, consumed.
        right: The second carrier, consumed; its successful payload is discarded.

    Returns:
        The carrier of retained left payloads.

    Raises:
        The family's construction error; deferred execution retains its own error.
    """
    return map2[I](_KeepOperand[I.Element[V], I.Element[W], True](), left^, right^)


def product_r[V: Movable & Deinitable, W: Movable & Deinitable, //, I: Applicative = downcast[_SourceFamily[V] if conforms_to(_SourceFamily[V], Applicative) else _UnrecognizedCarrier, Applicative]](var left: V, var right: W
) raises ProductRightContract[I, V, W].Error -> ProductRightContract[I, V, W].Out where ProductRightContract[I, V, W].Compatible:
    """Combine existing effects and keep the right payload on success.

    This has product_l's evaluation and ownership contract. Discarding the left
    payload does not discard its effect or its stored errors.

    Parameters:
        V: The complete left carrier type, including origins.
        W: The complete right carrier type, including origins.
        I: The Applicative family owning combination and errors; defaults to the first carrier's family.

    Args:
        left: The first carrier, consumed; its successful payload is discarded.
        right: The second carrier, consumed.

    Returns:
        The carrier of retained right payloads.

    Raises:
        The family's construction error; deferred execution retains its own error.
    """
    return map2[I](_KeepOperand[I.Element[V], I.Element[W], False](), left^, right^)
