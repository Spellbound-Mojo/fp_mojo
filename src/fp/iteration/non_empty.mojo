"""Total reductions justified by a NonEmptyList source."""
from fp.data.non_empty_list import NonEmptyList
from fp.algebra.protocols import Semigroup, _map_accumulate
from fp.algebra._accumulation import _OptionalCombine
from fp.callables.protocols import UnaryContract, BinaryContract, BorrowCallable
from fp.callables.invoke import RepeatableUnary, RepeatableBinary
from fp.callables.native import NativeUnary, NativeBinary, _Unary, _RaisingUnary, _Binary, _RaisingBinary, _NativeBorrow, _Borrowing, _RaisingBorrowing
from fp.callables._identity import Identity
from fp._internal.errors import _CommonError, _ErrorCompatible
from ._terminal import _reduce_optional
from ._advance import _Source, _source
from ._callbacks import _binary_repeated
from .reductions import _extremum


def reduce_non_empty[T: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](
    var step: F, var source: NonEmptyList[T]
) raises F.Error -> T where F.First == T and F.Second == T and F.Out == T and RepeatableBinary[F]:
    """Reduce from the first element without an Optional or empty-input error.

    The source invariant supplies the seed; no identity or copies are needed.
    Calls run left to right exactly n - 1 times. Callback failures propagate
    unchanged and destroy the accumulator and unvisited suffix.

    Parameters:
        T: The exact element and accumulator type, including origins.
        F: A shared or mutable binary callback with both inputs and output T.

    Args:
        step: The callback, consumed; singleton input skips it.
        source: The non-empty source, consumed.

    Returns:
        The final owned accumulator.

    Raises:
        The callback's exact error, including StopIteration as a callback failure.
    """
    comptime C = Pointer[F, origin_of(step)]
    var reduced = _reduce_optional[T, _Source[NonEmptyList[T]], F.Error, C,
        _binary_repeated[T, T, F, origin_of(step)]](Pointer(to=step), _source(source^))
    return reduced.unsafe_take()


def reduce_map[T: Movable & Deinitable, F: UnaryContract & Movable & Deinitable, //, S: Semigroup](
    var function: F, var source: NonEmptyList[T]
) raises _CommonError[F.Error, S.Error] -> S.Value where F.Arg == T and F.Out == S.Value and RepeatableUnary[F] and _ErrorCompatible[_CommonError[F.Error, S.Error], F.Error] and _ErrorCompatible[_CommonError[F.Error, S.Error], S.Error]:
    """Map and combine a non-empty source using only a Semigroup.

    The first mapped value seeds the accumulator. Mapping runs n times and
    combination n - 1 times, in source order, with no intermediate collection.
    Singleton input does not call combine. Only a common exact native error
    (or Never) is admitted, just as for ordinary fold_map.

    Parameters:
        T: The consumed element type, including native origins.
        F: A repeatable unary producer of S.Value.
        S: The ordered Semigroup; no empty identity is required.

    Args:
        function: The producer, consumed.
        source: The non-empty source, consumed.

    Returns:
        The owned, combined mapped value.

    Raises:
        The exact common callback and Semigroup error, stopping immediately.
    """
    comptime E = _CommonError[F.Error, S.Error]
    var result = _map_accumulate[NonEmptyList[T], F, _OptionalCombine[S], E](
        function^, source^, Optional[S.Value]())
    return result.unsafe_take()


def combine_non_empty[S: Semigroup](var source: NonEmptyList[S.Value]) raises S.Error -> S.Value:
    """Combine a non-empty source without constructing an identity.

    Parameters:
        S: The ordered Semigroup of source elements.

    Args:
        source: The non-empty source, consumed from left to right.

    Returns:
        Its sole value or its ordered reduction, without copying payloads.

    Raises:
        The Semigroup's exact error; singleton input cannot raise.
    """
    return reduce_map[S](Identity[S.Value](), source^)


def minimum_by_non_empty[T: Movable & Deinitable, C: BorrowCallable](var key: C, var source: NonEmptyList[T]
) raises C.Failure -> T where C.Payload == T and conforms_to(C.Result, Comparable):
    """Return the first minimum element of a non-empty source by an owned key.

    Keys are computed once per element through the ordinary extremum kernel.
    Elements are borrowed for projection and moved for retention. Equal keys
    keep the earlier element. No payload copies or Optional result are needed.

    Parameters:
        T: The consumed element type, including origins.
        C: A repeatable borrowing projection with a Comparable result.

    Args:
        key: The key projection, consumed.
        source: The non-empty source, consumed.

    Returns:
        The earliest element having a minimum key.

    Raises:
        The exact projection error, destroying partial state and the suffix.
    """
    var result = _extremum[NonEmptyList[T], T, C, True](key^, source^)
    return result.unsafe_take()


def maximum_by_non_empty[T: Movable & Deinitable, C: BorrowCallable](var key: C, var source: NonEmptyList[T]
) raises C.Failure -> T where C.Payload == T and conforms_to(C.Result, Comparable):
    """Return the first maximum element through the ordinary extremum kernel.

    Parameters:
        T: The consumed element type, including origins.
        C: A repeatable borrowing projection with a Comparable result.

    Args:
        key: The key projection, consumed and called once per element.
        source: The non-empty source, consumed; ties retain the first element.

    Returns:
        The earliest element having a maximum key, moved without copying.

    Raises:
        The exact projection error, destroying partial state and the suffix.
    """
    var result = _extremum[NonEmptyList[T], T, C, False](key^, source^)
    return result.unsafe_take()


def reduce_non_empty[T: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, //, F: _Binary[P, Q, R]](var step: F, var source: NonEmptyList[T]
) raises Never -> T where P == T and Q == T and R == T:
    """Reduce with an owned native binary function or closure."""
    return reduce_non_empty(NativeBinary[P, Q, R, Never, F, False](step^), source^)


def reduce_map[T: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, //, S: Semigroup, F: _Unary[A, R]](var function: F, var source: NonEmptyList[T]
) raises _CommonError[Never, S.Error] -> S.Value where A == T and R == S.Value and _ErrorCompatible[_CommonError[Never, S.Error], Never] and _ErrorCompatible[_CommonError[Never, S.Error], S.Error]:
    """Map and reduce with an owned native unary function or closure."""
    return reduce_map[S](NativeUnary[A, R, Never, F, False](function^), source^)


def minimum_by_non_empty[T: Movable & Deinitable, P: AnyType, R: Comparable & Movable & Deinitable, //, F: _Borrowing[P, R]](var key: F, var source: NonEmptyList[T]
) raises Never -> T where P == T:
    """Select by an owned native borrowing key projection."""
    return minimum_by_non_empty(_NativeBorrow[P, R, Never, F, False](key^), source^)


def maximum_by_non_empty[T: Movable & Deinitable, P: AnyType, R: Comparable & Movable & Deinitable, //, F: _Borrowing[P, R]](var key: F, var source: NonEmptyList[T]
) raises Never -> T where P == T:
    """Select by an owned native borrowing key projection."""
    return maximum_by_non_empty(_NativeBorrow[P, R, Never, F, False](key^), source^)


def reduce_non_empty[T: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, F: _RaisingBinary[P, Q, R, E]](var step: F, var source: NonEmptyList[T]
) raises E -> T where P == T and Q == T and R == T:
    """Reduce with an owned native binary function or closure."""
    return reduce_non_empty(NativeBinary[P, Q, R, E, F, True](step^), source^)


def reduce_map[T: Movable & Deinitable, A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, S: Semigroup, F: _RaisingUnary[A, R, E]](var function: F, var source: NonEmptyList[T]
) raises _CommonError[E, S.Error] -> S.Value where A == T and R == S.Value and _ErrorCompatible[_CommonError[E, S.Error], E] and _ErrorCompatible[_CommonError[E, S.Error], S.Error]:
    """Map and reduce with an owned native unary function or closure."""
    return reduce_map[S](NativeUnary[A, R, E, F, True](function^), source^)


def minimum_by_non_empty[T: Movable & Deinitable, P: AnyType, R: Comparable & Movable & Deinitable, E: Movable & Deinitable, //, F: _RaisingBorrowing[P, R, E]](var key: F, var source: NonEmptyList[T]
) raises E -> T where P == T:
    """Select by an owned native borrowing key projection."""
    return minimum_by_non_empty(_NativeBorrow[P, R, E, F, True](key^), source^)


def maximum_by_non_empty[T: Movable & Deinitable, P: AnyType, R: Comparable & Movable & Deinitable, E: Movable & Deinitable, //, F: _RaisingBorrowing[P, R, E]](var key: F, var source: NonEmptyList[T]
) raises E -> T where P == T:
    """Select by an owned native borrowing key projection."""
    return maximum_by_non_empty(_NativeBorrow[P, R, E, F, True](key^), source^)
