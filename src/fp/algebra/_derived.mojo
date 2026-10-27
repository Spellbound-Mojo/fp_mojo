"""Operations derived from the primitive protocols; no new execution paths."""
from fp.algebra._admission import _BindCompatible, _CombineCompatible, _CollectCompatible
from std.builtin.rebind import downcast
from fp.callables.protocols import UnaryContract, BinaryContract
from fp.callables._identity import Identity
from fp.callables._transforms import _ValueThunk as _Value, _Pair, _Apply
from .protocols import Applicative, Monad, Traversable
from fp._internal.errors import _ErrorCompatible, _propagate_error


def _map2_as[V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable,
             //, I: Applicative, X: Movable & Deinitable](
    var f: F, var left: V, var right: W
) raises X -> I.Combined[V, F, _Value[W]]:
    comptime assert _CombineCompatible[I, V, F, _Value[W]]
    # Native carrier syntax knows the exact callback error. Keep the family's
    # public symbolic error spelling intact and admit that identity here.
    try:
        return map2[I](f^, left^, right^)
    except error:
        comptime assert _ErrorCompatible[X, type_of(error)]
        _propagate_error[X](error^)


comptime _Same[T: Movable & Deinitable] = Identity[T]
comptime _Function[I: Applicative, V: Movable & Deinitable] = downcast[I.Element[V], UnaryContract & Movable & Deinitable]


def map2[V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, //, I: Applicative](
    var f: F, var left: V, var right: W
) raises I.CombineError[V, F, _Value[W]] -> I.Combined[V, F, _Value[W]] where _CombineCompatible[I, V, F, _Value[W]]:
    """Combine two carriers with `f`, where the right one is already computed.

    It is `map2_lazy` with a right operand that returns `right`.

    Parameters:
        V: The left carrier's type.
        W: The right carrier's type.
        F: The combiner's type: a library `Binary` value.
        I: The instance.

    Args:
        f: The combiner, consumed.
        left: The left carrier, consumed.
        right: The right carrier, consumed.

    Returns:
        The carrier of the combined payloads.

    Raises:
        The combiner's error.
    """
    return I.map2_lazy(f^, left^, _Value(right^))


def ap[V: Movable & Deinitable, W: Movable & Deinitable, //, I: Applicative](var functions: V, var values: W
) raises I.CombineError[V, _Apply[_Function[I, V]], _Value[W]] -> I.Combined[V, _Apply[_Function[I, V]], _Value[W]] where _CombineCompatible[I, V, _Apply[_Function[I, V]], _Value[W]]:
    """Apply the callbacks a carrier holds to the values another carrier holds.

    Parameters:
        V: The type of the carrier of callbacks, which are library `Unary` values.
        W: The type of the carrier of values.
        I: The instance.

    Args:
        functions: The carrier of callbacks, consumed.
        values: The carrier of values, consumed.

    Returns:
        The carrier of the results; for lists, every callback applied to every
        value in left-major order.

    Raises:
        The callbacks' error.
    """
    return I.map2_lazy(_Apply[_Function[I, V]](), functions^, _Value(values^))


def flatten[V: Movable & Deinitable, //, I: Monad](var nested: V
) raises I.BindError[V, _Same[I.Element[V]]] -> I.Bound[V, _Same[I.Element[V]]] where _BindCompatible[I, V, _Same[I.Element[V]]]:
    """Remove one level of the same context: `flat_map` with the identity.

    Parameters:
        V: The nested carrier's type, such as `Optional[Optional[A]]`.
        I: The instance.

    Args:
        nested: The nested carrier, consumed.

    Returns:
        The inner carrier, or the outer context when there is no payload.

    Raises:
        The instance's bind error; the identity callback itself raises nothing.
    """
    return I.flat_map(Identity[I.Element[V]](), nested^)


def sequence[V: Movable & Deinitable, //, S: Traversable, G: Applicative](var source: V
) raises S.TraverseError[G, V, _Same[S.Element[V]]] -> S.Traversed[G, V, _Same[S.Element[V]]] where S.TargetCompatible[G, V, _Same[S.Element[V]]]:
    """Turn a source of `G` carriers into one `G` carrier of the source: `traverse` with the identity.

    Parameters:
        V: The source's type, such as `List[Optional[A]]`.
        S: The source's instance.
        G: The carriers' instance.

    Args:
        source: The source, consumed.

    Returns:
        `G`'s carrier of the payloads in source shape; it stops at the first
        failure.

    Raises:
        Any error `G` adds.
    """
    return S.traverse[G](Identity[S.Element[V]](), source^)


def product[V: Movable & Deinitable, W: Movable & Deinitable, //, I: Applicative](var left: V, var right: W
) raises I.CombineError[V, _Pair[I.Element[V], I.Element[W]], _Value[W]] -> I.Combined[V, _Pair[I.Element[V], I.Element[W]], _Value[W]] where _CombineCompatible[I, V, _Pair[I.Element[V], I.Element[W]], _Value[W]]:
    """Combine already computed operands into pairs through map2.

    Parameters:
        V: The left carrier type, including origins.
        W: The right carrier type, including origins.
        I: The Applicative family, which defines combination and errors.

    Args:
        left: The first carrier, consumed.
        right: The second carrier, consumed; already evaluated.

    Returns:
        The carrier of pairs. Lists form a Cartesian product in left-major order.

    Raises:
        The family's combination error, unchanged.
    """
    return map2[I](_Pair[I.Element[V], I.Element[W]](), left^, right^)
