"""Error-accumulating traversal without naming the error semigroup."""
from std.builtin.rebind import downcast
from std.iter import IterableOwned
from .protocols import Applicative, _Accumulate
from .validation import ValidationFamily, _ListErrors
from .instances import _ListElement
from .collections import _UnrecognizedCarrier, _NoElement
from fp.data._result import _ResultType
from fp.callables.protocols import UnaryContract, BinaryContract, ThunkContract


# The policy a callback's `Result[T, List[E]]` selects: Validation with list
# concatenation, as accumulating Validation traversal infers its default.
comptime _AccumulatingFor[R: Movable & Deinitable] = ValidationFamily[_ListErrors[R]]

# Guard each projection: a Result whose stored error is a native List.
comptime _ListErrorResult[R: Movable & Deinitable]: Bool = (
    (downcast[R, _ResultType].Error == List[_ListElement[downcast[R, _ResultType].Error]]
     if conforms_to(downcast[R, _ResultType].Error, IterableOwned) else False)
    if conforms_to(R, _ResultType) else False
)


struct Accumulate(Applicative):
    """Traverse into Result, collecting every error instead of stopping at the first.

    `traverse[Accumulate](values, check)` runs `check` on every element. With
    `check` returning `Result[T, List[E]]`, the outcome is `Ok` of all payloads
    or `Err` of every error list concatenated in source order. It selects
    `ValidationFamily[ListMonoid[E]]` from the callback's result, so the error
    semigroup needs no name; name `ValidationFamily[S]` for another policy or a
    non-list error. Native raises still stop immediately.

    Only collection is supported: traversing List and other sequence sources,
    from free functions, Iter and Pipeline. Other Applicative operations
    and single-payload sources are rejected at the call.
    """
    comptime Element[V: Movable & Deinitable] = _NoElement
    comptime CarrierCompatible[V: Movable & Deinitable]: Bool = (
        _AccumulatingFor[V].CarrierCompatible[V] if _ListErrorResult[V] else False
    )
    comptime MapCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool = False
    comptime CombineCompatible[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable]: Bool = False
    comptime _LoopCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate]: Bool = False
    comptime Mapped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _NoElement
    comptime MapError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Never
    comptime Pure[A: Movable & Deinitable] = _NoElement
    comptime Combined[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = _NoElement
    comptime CombineError[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable] = Never
    comptime _Looped[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = _NoElement
    comptime _LoopError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate] = Never
    # Collection is the selected Validation family's, guarded by the callback
    # returning a Result whose error is a List.
    comptime CollectCompatible[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable]: Bool = (
        _AccumulatingFor[F.Out].CollectCompatible[V, F] if _ListErrorResult[F.Out] else False
    )
    comptime Collected[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _AccumulatingFor[F.Out].Collected[V, F]
    comptime CollectError[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = _AccumulatingFor[F.Out].CollectError[V, F]

    @staticmethod
    def collect[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var source: V
    ) raises Self.CollectError[V, F] -> Self.Collected[V, F]:
        """Collect through the Validation family the callback's result selects.

        Parameters:
            V: The source's type: an iterator or an owned iterable.
            F: The repeatable callback's type, returning `Result[T, List[E]]`.

        Args:
            f: The callback, consumed.
            source: The source, consumed.

        Returns:
            `Ok` of every payload, or `Err` of all errors in source order.

        Raises:
            The callback's native error.
        """
        return _AccumulatingFor[F.Out].collect[V, F](f^, source^)

    # No admission holds for the remaining operations; they delegate to the
    # rejecting family and never run.
    @staticmethod
    def map[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var value: V) -> _NoElement:
        """Unsupported: mapping admits no carrier, so it is never called.

        Parameters:
            V: The rejected carrier type.
            F: The rejected callback type.

        Args:
            f: The callback, consumed.
            value: The carrier, consumed.

        Returns:
            An uninhabited placeholder.
        """
        return _UnrecognizedCarrier.map(f^, value^)

    @staticmethod
    def pure[A: Movable & Deinitable](var value: A) -> _NoElement:
        """Unsupported: the error type comes from a callback, which pure lacks.

        Parameters:
            A: The payload type.

        Args:
            value: The payload, consumed.

        Returns:
            An uninhabited placeholder.
        """
        return _UnrecognizedCarrier.pure(value^)

    @staticmethod
    def map2_lazy[V: Movable & Deinitable, F: BinaryContract & Movable & Deinitable, R: ThunkContract & Movable & Deinitable](var f: F, var left: V, var right: R) -> _NoElement:
        """Unsupported: combination admits no carrier, so it is never called.

        Parameters:
            V: The rejected left carrier type.
            F: The rejected combiner type.
            R: The rejected right thunk type.

        Args:
            f: The combiner, consumed.
            left: The left carrier, consumed.
            right: The right thunk, consumed.

        Returns:
            An uninhabited placeholder.
        """
        return _UnrecognizedCarrier.map2_lazy(f^, left^, right^)

    @staticmethod
    def _loop[V: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, K: _Accumulate](var f: F, var source: V) -> _NoElement:
        return _UnrecognizedCarrier._loop[V, F, K](f^, source^)
