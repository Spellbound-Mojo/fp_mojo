"""Operations derived from the primitive protocols; no new execution paths."""
from std.builtin.rebind import downcast
from fp.callables.protocols import UnaryContract, BinaryContract, Binary, OnceThunk
from fp.callables.invoke import call_once
from fp.functions.composition import Identity
from .protocols import Applicative, Monad, Traversable


@fieldwise_init
struct _Value[T: Movable & Deinitable](OnceThunk, Copyable where conforms_to(T, Copyable)):
    """An already computed right operand."""
    var value: Self.T
    comptime Out = Self.T
    def call_once(deinit self) -> Self.Out:
        return self.value^


@fieldwise_init
struct _Apply[U: UnaryContract & Movable & Deinitable](Binary, Copyable, Defaultable):
    """Call the left element, a unary callback, with the right element."""
    comptime First = Self.U
    comptime Second = Self.U.Arg
    comptime Out = Self.U.Out
    comptime Error = Self.U.Error
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        return call_once(first^, second^)


comptime _Same[T: Movable & Deinitable] = Identity[T]
comptime _Function[I: Applicative, V: Movable & Deinitable] = downcast[I.Element[V], UnaryContract & Movable & Deinitable]


def map2[V: Movable & Deinitable, W: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, //, I: Applicative](
    var f: F, var left: V, var right: W
) raises I.CombineError[V, F, _Value[W]] -> I.Combined[V, F, _Value[W]]:
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
) raises I.CombineError[V, _Apply[_Function[I, V]], _Value[W]] -> I.Combined[V, _Apply[_Function[I, V]], _Value[W]]:
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
) raises I.BindError[V, _Same[I.Element[V]]] -> I.Bound[V, _Same[I.Element[V]]]:
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
) raises S.TraverseError[G, V, _Same[S.Element[V]]] -> S.Traversed[G, V, _Same[S.Element[V]]]:
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
