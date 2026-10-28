"""Sequential terminal folds over native sources.

A source is a native iterator or an owned collection (`IterableOwned`), which is
consumed. Use `std.iter.iter` to iterate a collection by reference.
"""

from std.iter import Iterator
from std.builtin.rebind import rebind_var
from fp._internal.errors import _propagate_error
from std.utils import Variant
from fp.data.control import ControlFlow
from fp.iteration._callbacks import _binary_plain, _binary_raising, _control_plain, _control_raising
from fp.iteration._terminal import _fold_left, _fold_until, _reduce_optional
from fp.iteration._advance import _Source, _source
from fp.callables.protocols import Binary, BinaryContract
from fp.callables.invoke import RepeatableBinary
from fp.iteration._callbacks import _binary_fixed, _control_fixed, _binary_repeated


def fold_left[A: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, I: Movable & Deinitable, //,
              F: def(var P, var Q) -> R, T: Movable & Deinitable = Q](
    step: F, var initial: A, var iterator: I
) -> A where _Source[I].Element == T and P == A and Q == T and R == A:
    """Fold a source from the left: `step(... step(step(initial, x0), x1) ..., xn)`.

    Each element is moved into `step` with the accumulator, in order, and the
    steps are never reassociated. The accumulator and element types may differ;
    scalars, SIMD values (whose lanes are never reduced implicitly) and any other
    accumulator work alike. Empty input returns `initial` without a call.

    Parameters:
        A: The accumulator type.
        P: The callback accumulator input, inferred with its origins.
        Q: The callback element input, inferred with its origins.
        R: The callback result, inferred with its origins.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The step's type: a plain function or a closure.
        T: The requested element type, which must match the callback and source.

    Args:
        step: The step, borrowed; it is called once per element.
        initial: The first accumulator, consumed.
        iterator: The source, consumed.

    Returns:
        The final accumulator.
    """
    return _fold_left[A, T, _Source[I], Never, F, _binary_plain[P, Q, R, F, A, T, A]](
        step, initial^, _source(iterator^)
    )

def reduce_optional[P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, I: Movable & Deinitable, //,
                    F: def(var P, var Q) -> R, T: Movable & Deinitable = Q](
    step: F, var iterator: I
) -> Optional[T] where _Source[I].Element == T and P == T and Q == T and R == T:
    """Reduce a source with its first element as the accumulator; empty input gives `None`.

    Only empty input becomes absence. The step runs outside the boundary that
    detects exhaustion, so a step that raises `StopIteration` fails as a step.

    Parameters:
        P: The callback accumulator input, inferred with its origins.
        Q: The callback element input, inferred with its origins.
        R: The callback result, inferred with its origins.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The step's type: a plain function or a closure.
        T: The requested element and accumulator type; all callback types must match it.

    Args:
        step: The step, borrowed; it is called once per element after the first.
        iterator: The source, consumed.

    Returns:
        The final accumulator, or `None` for an empty source.
    """
    return _reduce_optional[T, _Source[I], Never, F, _binary_plain[P, Q, R, F, T, T, T]](
        step, _source(iterator^)
    )


def fold_left[A: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, I: Movable & Deinitable, E: AnyType, //,
              F: def(var P, var Q) raises E -> R, T: Movable & Deinitable = Q](
    step: F, var initial: A, var iterator: I
) raises E -> A where _Source[I].Element == T and P == A and Q == T and R == A:
    """Fold with a raising step; its error stops the fold with its own type."""
    return _fold_left[A, T, _Source[I], E, F, _binary_raising[P, Q, R, E, F, A, T, A]](
        step, initial^, _source(iterator^)
    )

def reduce_optional[P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, I: Movable & Deinitable, E: AnyType, //,
                    F: def(var P, var Q) raises E -> R, T: Movable & Deinitable = Q](
    step: F, var iterator: I
) raises E -> Optional[T] where _Source[I].Element == T and P == T and Q == T and R == T:
    """Reduce with a raising step; empty input gives `None`, and the step's error is kept."""
    return _reduce_optional[T, _Source[I], E, F, _binary_raising[P, Q, R, E, F, T, T, T]](
        step, _source(iterator^)
    )

def fold_until[A: Movable & Deinitable, Q: Movable & Deinitable,
               P: Movable & Deinitable, R: Movable & Deinitable, S: Movable & Deinitable, I: Movable & Deinitable, //,
               F: def(var P, var S) -> ControlFlow[Q, R], B: Movable & Deinitable = Q, T: Movable & Deinitable = S](
    step: F, var initial: A, var iterator: I
) -> ControlFlow[B, A] where _Source[I].Element == T and Q == B and P == A and R == A and S == T:
    """Fold until a step returns `Break`, without pulling another element.

    Each step returns `Continue(accumulator)` to go on or `Break(value)` to stop
    at once; the element that caused the break has been consumed. Exhaustion
    returns `Continue` with the last accumulator, or `initial` for empty input.

    Parameters:
        A: The accumulator type.
        Q: The callback's break payload type, inferred with its origins.
        P: The callback accumulator input, inferred with its origins.
        R: The callback continue payload, inferred with its origins.
        S: The callback element input, inferred with its origins.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The step's type: a plain function or a closure returning `ControlFlow[B, A]`.
        B: The requested break payload type; defaults to `Q` and must match it.
        T: The requested element type, which must match the callback and source.

    Args:
        step: The step, borrowed.
        initial: The first accumulator, consumed.
        iterator: The source, consumed.

    Returns:
        The first `Break`, or `Continue` with the final accumulator.
    """
    # Infer the native inputs and outputs independently before checking exact
    # carry, element and break types. The shared bridge adapts only equal types.
    return rebind_var[ControlFlow[B, A]](_fold_until[A, Q, T, _Source[I], Never, F,
        _control_plain[P, Q, S, R, F, A, T, A, Q]](step, initial^, _source(iterator^)))

def fold_until[A: Movable & Deinitable, Q: Movable & Deinitable,
               P: Movable & Deinitable, R: Movable & Deinitable, S: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //,
               F: def(var P, var S) raises E -> ControlFlow[Q, R], B: Movable & Deinitable = Q, T: Movable & Deinitable = S](
    step: F, var initial: A, var iterator: I
) raises E -> ControlFlow[B, A] where _Source[I].Element == T and Q == B and P == A and R == A and S == T:
    """Fold until `Break` with a raising step; its error is a separate outcome from `Break`."""
    return rebind_var[ControlFlow[B, A]](_fold_until[A, Q, T, _Source[I], E, F,
        _control_raising[P, Q, S, E, R, F, A, T, A, Q]](step, initial^, _source(iterator^)))


@fieldwise_init
struct EmptyReductionError(Copyable, Movable, Writable):
    """The error of `reduce` without an initial value on an empty source."""
    pass


def reduce[A: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, I: Movable & Deinitable, //,
           F: def(var P, var Q) -> R, T: Movable & Deinitable = Q](step: F, var iterator: I, *, var initial: A) -> A where _Source[I].Element == T and P == A and Q == T and R == A:
    """Reduce a source from an initial value: the same as `fold_left`.

    Parameters:
        A: The accumulator type.
        P: The callback accumulator input, inferred with its origins.
        Q: The callback element input, inferred with its origins.
        R: The callback result, inferred with its origins.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The step's type: a plain function or a closure.
        T: The requested element type, which must match the callback and source.

    Args:
        step: The step, borrowed; it is called once per element.
        iterator: The source, consumed.
        initial: The first accumulator, consumed; returned for empty input.

    Returns:
        The final accumulator.
    """
    return fold_left[A=A, P=P, Q=Q, R=R, T=T, I=I, F=F](step, initial^, iterator^)


def reduce[P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, I: Movable & Deinitable, //,
           F: def(var P, var Q) -> R, T: Movable & Deinitable = Q](step: F, var iterator: I) raises EmptyReductionError -> T where _Source[I].Element == T and P == T and Q == T and R == T:
    """Reduce a source with its first element as the accumulator.

    Parameters:
        P: The callback accumulator input, inferred with its origins.
        Q: The callback element input, inferred with its origins.
        R: The callback result, inferred with its origins.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        F: The step's type: a plain function or a closure.
        T: The requested element and accumulator type; all callback types must match it.

    Args:
        step: The step, borrowed; it is called once per element after the first.
        iterator: The source, consumed.

    Returns:
        The final accumulator.

    Raises:
        `EmptyReductionError` when the source is empty.
    """
    return _reduce_value[T, _Source[I], Never, F, _binary_plain[P, Q, R, F, T, T, T]](step, _source(iterator^))


@fieldwise_init
struct ReductionStepError[E: Movable & Deinitable](
    Movable, Copyable where conforms_to(E, Copyable)
):
    """A reduction step's error, kept distinct from empty input.

    A step that itself raises `EmptyReductionError` is still reported in this
    alternative.

    Parameters:
        E: The step's error type.
    """
    var error: Self.E
    """The step's error, unchanged."""

    def into_error(deinit self) -> Self.E:
        """Consume the wrapper and return the step's error.

        Returns:
            The step's error, moved out.
        """
        return self.error^


comptime ReductionError[E: Movable & Deinitable] = Variant[
    EmptyReductionError, ReductionStepError[E]
]
"""The error of a raising `reduce` without an initial value: empty input, or the step's error.

A native `Variant`; check which alternative is active before taking it.

Parameters:
    E: The step's error type.
"""


def reduce[A: Movable & Deinitable, P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, I: Movable & Deinitable,
           E: Movable & Deinitable, //,
           F: def(var P, var Q) raises E -> R, T: Movable & Deinitable = Q](
    step: F, var iterator: I, *, var initial: A
) raises E -> A where _Source[I].Element == T and P == A and Q == T and R == A:
    """Reduce from an initial value with a raising step; its error is kept."""
    return fold_left[A=A, P=P, Q=Q, R=R, T=T, I=I, E=E, F=F](step, initial^, iterator^)


def reduce[P: Movable & Deinitable, Q: Movable & Deinitable, R: Movable & Deinitable, I: Movable & Deinitable, E: Movable & Deinitable, //,
           F: def(var P, var Q) raises E -> R, T: Movable & Deinitable = Q](
    step: F, var iterator: I
) raises ReductionError[E] -> T where _Source[I].Element == T and P == T and Q == T and R == T:
    """Reduce with a raising step and no initial value.

    Empty input and a step's error are two different failures, so they raise
    two alternatives of one `Variant`.

    Parameters:
        P: The callback accumulator input, inferred with its origins.
        Q: The callback element input, inferred with its origins.
        R: The callback result, inferred with its origins.
        I: The source's type: a native iterator, or an owned collection
            (`IterableOwned`, such as `List`), which is consumed.
        E: The step's error type.
        F: The step's type: a plain function or a closure that raises `E`.
        T: The requested element and accumulator type; all callback types must match it.

    Args:
        step: The step, borrowed; it is called once per element after the first.
        iterator: The source, consumed.

    Returns:
        The final accumulator.

    Raises:
        `ReductionError[E]`: `EmptyReductionError` for an empty source, or
        `ReductionStepError[E]` holding the step's error.
    """
    return _reduce_value[T, _Source[I], E, F, _binary_raising[P, Q, R, E, F, T, T, T], True](step, _source(iterator^))


# Fixed-arity library steps with a shared receiver, such as partials, through
# the same terminal drivers.
def fold_left[A: Movable & Deinitable, I: Movable & Deinitable, F: Binary](
    step: F, var initial: A, var iterator: I
) raises F.Error -> A where F.First == A and F.Second == _Source[I].Element and F.Out == A:
    """Fold with a library `Binary` step, such as a partial with two remaining arguments."""
    return _fold_left[A, F.Second, _Source[I], F.Error, F, _binary_fixed[A, F.Second, F]](step, initial^, _source(iterator^))


def reduce_optional[I: Movable & Deinitable, F: Binary](
    step: F, var iterator: I
) raises F.Error -> Optional[F.Out] where F.First == F.Out and F.Second == F.Out and _Source[I].Element == F.Out:
    """Reduce with a library `Binary` step; empty input gives `None`."""
    return _reduce_optional[F.Out, _Source[I], F.Error, F, _binary_fixed[F.Out, F.Out, F]](step, _source(iterator^))


def reduce[A: Movable & Deinitable, I: Movable & Deinitable, F: Binary](
    step: F, var iterator: I, *, var initial: A
) raises F.Error -> A where F.First == A and F.Second == _Source[I].Element and F.Out == A:
    """Reduce from an initial value with a library `Binary` step."""
    return fold_left(step, initial^, iterator^)


def reduce[I: Movable & Deinitable, F: Binary](
    step: F, var iterator: I
) raises _ReductionFailure[F.Error] -> F.Out where F.First == F.Out and F.Second == F.Out and _Source[I].Element == F.Out:
    """Reduce with a library `Binary` step and no initial value."""
    return _reduce_value[F.Out, _Source[I], F.Error, F, _binary_fixed[F.Out, F.Out, F]](step, _source(iterator^))


def fold_until[B: Movable & Deinitable, A: Movable & Deinitable, I: Movable & Deinitable, F: Binary](
    step: F, var initial: A, var iterator: I
) raises F.Error -> ControlFlow[B, A] where F.First == A and F.Second == _Source[I].Element and F.Out == ControlFlow[B, A]:
    """Fold until `Break` with a library `Binary` step."""
    return _fold_until[A, B, F.Second, _Source[I], F.Error, F, _control_fixed[A, B, F.Second, F]](step, initial^, _source(iterator^))


# The public native overload distinguishes an explicitly raising callback from a
# nonraising one even when its error is Never. Library callables express effects
# through Error, so Never selects the nonraising reduction contract.
comptime _ReductionFailure[E: Movable & Deinitable, raising: Bool = E != Never] = ReductionError[E] if raising else EmptyReductionError


def _reduce_value[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable,
                  F: AnyType, apply: def(var T, var T, F) raises E capturing -> T,
                  raising: Bool = E != Never](step: F, var iterator: I
) raises _ReductionFailure[E, raising] -> T where I.Element == T:
    var result: Optional[T]
    try:
        result = _reduce_optional[T, I, E, F, apply](step, iterator^)
    except error:
        comptime if raising:
            comptime assert _ReductionFailure[E, raising] == ReductionError[E]
            raise rebind_var[_ReductionFailure[E, raising]](ReductionError[E](ReductionStepError[E](error^)))
        else:
            comptime assert E == Never
            _propagate_error[_ReductionFailure[E, raising]](error^)
    if not result:
        comptime if raising:
            comptime assert _ReductionFailure[E, raising] == ReductionError[E]
            raise rebind_var[_ReductionFailure[E, raising]](ReductionError[E](EmptyReductionError()))
        else:
            comptime assert _ReductionFailure[E, raising] == EmptyReductionError
            raise rebind_var[_ReductionFailure[E, raising]](EmptyReductionError())
    return result.take()


# --- iterator expansion syntax (generated) ---
# Generated by scripts/generate_plain_overloads.py; algorithms live in the operation owners.

def fold_left[A: Movable & Deinitable, I: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var step: F, var initial: A, var iterator: I) raises F.Error -> A where F.First == A and F.Second == _Source[I].Element and F.Out == A and RepeatableBinary[F]:
    """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
    """
    return _fold_left[A, F.Second, _Source[I], F.Error, Pointer[F, origin_of(step)], _binary_repeated[A, F.Second, F, origin_of(step), A]](Pointer(to=step), initial^, _source(iterator^))

def reduce[A: Movable & Deinitable, I: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var step: F, var iterator: I, *, var initial: A) raises F.Error -> A where F.First == A and F.Second == _Source[I].Element and F.Out == A and RepeatableBinary[F]:
    """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
    """
    return fold_left[A=A, F=F](step^, initial^, iterator^)

def reduce_optional[I: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var step: F, var iterator: I) raises F.Error -> Optional[F.Out] where F.First == F.Out and F.Second == F.Out and _Source[I].Element == F.Out and RepeatableBinary[F]:
    """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
    """
    return _reduce_optional[F.Out, _Source[I], F.Error, Pointer[F, origin_of(step)], _binary_repeated[F.Out, F.Out, F, origin_of(step), F.Out]](Pointer(to=step), _source(iterator^))

def reduce[I: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var step: F, var iterator: I) raises _ReductionFailure[F.Error] -> F.Out where F.First == F.Out and F.Second == F.Out and _Source[I].Element == F.Out and RepeatableBinary[F]:
    """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
    """
    return _reduce_value[F.Out, _Source[I], F.Error, Pointer[F, origin_of(step)], _binary_repeated[F.Out, F.Out, F, origin_of(step), F.Out]](Pointer(to=step), _source(iterator^))

def fold_until[B: Movable & Deinitable, A: Movable & Deinitable, I: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var step: F, var initial: A, var iterator: I) raises F.Error -> ControlFlow[B, A] where F.First == A and F.Second == _Source[I].Element and F.Out == ControlFlow[B, A] and RepeatableBinary[F]:
    """Consume a repeatable library step, preserving its mutable receiver and exact fold contract.
    """
    return _fold_until[A, B, F.Second, _Source[I], F.Error, Pointer[F, origin_of(step)], _binary_repeated[A, F.Second, F, origin_of(step), ControlFlow[B, A]]](Pointer(to=step), initial^, _source(iterator^))
# --- end iterator expansion syntax ---
