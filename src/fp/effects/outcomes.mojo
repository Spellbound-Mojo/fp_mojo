"""Typed failure accumulation shared by resource scopes and IO finalization."""
from std.builtin.rebind import rebind_var
from fp.data import Result, Ok, Err, NonEmptyList, attempt_once
from fp.callables.protocols import OnceThunk, ThunkContract, UnaryContract
from fp.callables.invoke import _OnceUnaryAvailable, _OnceThunkAvailable
from fp.callables._receiver import _thunk_once_as
from fp.callables.native import NativeUnary, _NativeThunk, _Unary, _RaisingUnary, _Thunk, _RaisingThunk
from fp._internal.errors import _ErrorCompatible, _absurd, _CommonError, _CommonErrorCompatible, _propagate_error


@fieldwise_init
struct EffectFailure[E: Movable & Deinitable](Movable, Copyable where conforms_to(E, Copyable)):
    """One or more exact errors, with cancellation recorded independently.

    Errors retain their occurrence order: body first, then finalizers from the
    innermost scope outwards. Neither errors nor their borrowed origins are
    erased. Native resource scopes always set canceled to False.

    Parameters:
        E: The selected native error type; payloads may be move-only.
    """
    var errors: NonEmptyList[Self.E]
    """The non-empty sequence of errors, in execution order."""
    var canceled: Bool
    """Whether cancellation also occurred during the failed operation."""

    def into_errors(deinit self) -> NonEmptyList[Self.E]:
        """Consume this failure and transfer its error collection.

        Returns:
            The original non-empty collection, without copying its elements.
        """
        # Consume the complete wrapper before a caller splits linear List
        # storage; partial nested field destruction is rejected by Mojo 1.2.
        return self.errors^


comptime Outcome[T: Movable & Deinitable, E: Movable & Deinitable] = Optional[Result[T, EffectFailure[E]]]
"""An IO outcome: absent for cancellation, present Ok for success or Err for failure.

A failure may also record cancellation when a finalizer fails after cancellation.

Parameters:
    T: The owned success type.
    E: The exact error payload type, collected by EffectFailure.
"""


struct FoldOutcomeContract[T: Movable & Deinitable, E: Movable & Deinitable,
                          F: UnaryContract & Movable & Deinitable,
                          G: UnaryContract & Movable & Deinitable,
                          H: ThunkContract & Movable & Deinitable]:
    """Exact admission and callback result for consuming a completed outcome.

    Parameters:
        T: The owned successful payload type.
        E: The native error type stored in the complete EffectFailure.
        F: The once-callable success handler.
        G: The once-callable failure handler.
        H: The once-callable cancellation thunk.
    """
    comptime Out = Self.F.Out
    """The common handler result, retaining its native origins."""
    comptime Error = _CommonError[_CommonError[Self.F.Error, Self.G.Error], Self.H.Error]
    """The exact compatible native callback error, or Never."""
    comptime Compatible = (
        Self.F.Arg == Self.T and Self.G.Arg == EffectFailure[Self.E] and
        Self.F.Out == Self.G.Out and Self.F.Out == Self.H.Out and
        _OnceUnaryAvailable[Self.F] and _OnceUnaryAvailable[Self.G] and _OnceThunkAvailable[Self.H] and
        _CommonErrorCompatible[Self.F.Error, Self.G.Error] and
        _CommonErrorCompatible[_CommonError[Self.F.Error, Self.G.Error], Self.H.Error]
    )
    """Exact inputs, common output and native errors, with available receivers."""


def fold_outcome[T: Movable & Deinitable, E: Movable & Deinitable,
                 F: UnaryContract & Movable & Deinitable,
                 G: UnaryContract & Movable & Deinitable,
                 H: ThunkContract & Movable & Deinitable](
    var outcome: Outcome[T, E], var on_success: F, var on_failure: G, var on_cancel: H
) raises FoldOutcomeContract[T, E, F, G, H].Error -> FoldOutcomeContract[T, E, F, G, H].Out where FoldOutcomeContract[T, E, F, G, H].Compatible:
    """Consume an outcome and invoke exactly its selected handler.

    A failure transfers the complete EffectFailure, including cancellation and
    all stored errors. The cancellation thunk runs only for an absent outcome.
    Unselected callbacks and their captures are destroyed without invocation.

    Parameters:
        T: The owned successful payload type.
        E: The stored native error type.
        F: The consuming success handler's type.
        G: The consuming failure handler's type.
        H: The cancellation thunk's type.

    Args:
        outcome: The completed outcome, consumed once.
        on_success: Receives the successful T.
        on_failure: Receives the complete EffectFailure[E].
        on_cancel: Produces the result for cancellation-only completion.

    Returns:
        The selected callback result, without copying values or errors.

    Raises:
        The exact compatible native error of the selected callback.
    """
    comptime C = FoldOutcomeContract[T, E, F, G, H]
    comptime assert _ErrorCompatible[C.Error, H.Error]
    comptime assert _ErrorCompatible[C.Error, _CommonError[F.Error, G.Error]]
    if not outcome:
        return rebind_var[C.Out](_thunk_once_as[C.Error](on_cancel^))
    try:
        return outcome.take().fold_owned_once(on_success^, on_failure^)
    except error:
        _propagate_error[C.Error](error^)


# Infer native operand conventions before checking exact outcome inputs.
# Fixing T in the function bound rejects ordinary register-passed arguments
# on Mojo 1.2; the signature equality preserves origins after inference.
def fold_outcome[T: Movable & Deinitable, E: Movable & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //, F: _Unary[A, R], G: _Unary[B, R], H: _Thunk[R]](
    var outcome: Outcome[T, E], var on_success: F, var on_failure: G, var on_cancel: H
) -> R where A == T and B == EffectFailure[E]:
    """Consume an outcome with owned native handlers and their exact shared error type."""
    return fold_outcome(outcome^, NativeUnary[A, R, Never, F, False](on_success^), NativeUnary[B, R, Never, G, False](on_failure^), _NativeThunk[R, Never, H, False](on_cancel^))


def fold_outcome[T: Movable & Deinitable, E: Movable & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _Unary[A, R], G: _Unary[B, R], H: _RaisingThunk[R, X]](
    var outcome: Outcome[T, E], var on_success: F, var on_failure: G, var on_cancel: H
) raises X -> R where A == T and B == EffectFailure[E]:
    """Consume an outcome with owned native handlers and their exact shared error type."""
    return fold_outcome(outcome^, NativeUnary[A, R, Never, F, False](on_success^), NativeUnary[B, R, Never, G, False](on_failure^), _NativeThunk[R, X, H, True](on_cancel^))


def fold_outcome[T: Movable & Deinitable, E: Movable & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _Unary[A, R], G: _RaisingUnary[B, R, X], H: _Thunk[R]](
    var outcome: Outcome[T, E], var on_success: F, var on_failure: G, var on_cancel: H
) raises X -> R where A == T and B == EffectFailure[E]:
    """Consume an outcome with owned native handlers and their exact shared error type."""
    return fold_outcome(outcome^, NativeUnary[A, R, Never, F, False](on_success^), NativeUnary[B, R, X, G, True](on_failure^), _NativeThunk[R, Never, H, False](on_cancel^))


def fold_outcome[T: Movable & Deinitable, E: Movable & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _Unary[A, R], G: _RaisingUnary[B, R, X], H: _RaisingThunk[R, X]](
    var outcome: Outcome[T, E], var on_success: F, var on_failure: G, var on_cancel: H
) raises X -> R where A == T and B == EffectFailure[E]:
    """Consume an outcome with owned native handlers and their exact shared error type."""
    return fold_outcome(outcome^, NativeUnary[A, R, Never, F, False](on_success^), NativeUnary[B, R, X, G, True](on_failure^), _NativeThunk[R, X, H, True](on_cancel^))


def fold_outcome[T: Movable & Deinitable, E: Movable & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingUnary[A, R, X], G: _Unary[B, R], H: _Thunk[R]](
    var outcome: Outcome[T, E], var on_success: F, var on_failure: G, var on_cancel: H
) raises X -> R where A == T and B == EffectFailure[E]:
    """Consume an outcome with owned native handlers and their exact shared error type."""
    return fold_outcome(outcome^, NativeUnary[A, R, X, F, True](on_success^), NativeUnary[B, R, Never, G, False](on_failure^), _NativeThunk[R, Never, H, False](on_cancel^))


def fold_outcome[T: Movable & Deinitable, E: Movable & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingUnary[A, R, X], G: _Unary[B, R], H: _RaisingThunk[R, X]](
    var outcome: Outcome[T, E], var on_success: F, var on_failure: G, var on_cancel: H
) raises X -> R where A == T and B == EffectFailure[E]:
    """Consume an outcome with owned native handlers and their exact shared error type."""
    return fold_outcome(outcome^, NativeUnary[A, R, X, F, True](on_success^), NativeUnary[B, R, Never, G, False](on_failure^), _NativeThunk[R, X, H, True](on_cancel^))


def fold_outcome[T: Movable & Deinitable, E: Movable & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingUnary[A, R, X], G: _RaisingUnary[B, R, X], H: _Thunk[R]](
    var outcome: Outcome[T, E], var on_success: F, var on_failure: G, var on_cancel: H
) raises X -> R where A == T and B == EffectFailure[E]:
    """Consume an outcome with owned native handlers and their exact shared error type."""
    return fold_outcome(outcome^, NativeUnary[A, R, X, F, True](on_success^), NativeUnary[B, R, X, G, True](on_failure^), _NativeThunk[R, Never, H, False](on_cancel^))


def fold_outcome[T: Movable & Deinitable, E: Movable & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable, //, F: _RaisingUnary[A, R, X], G: _RaisingUnary[B, R, X], H: _RaisingThunk[R, X]](
    var outcome: Outcome[T, E], var on_success: F, var on_failure: G, var on_cancel: H
) raises X -> R where A == T and B == EffectFailure[E]:
    """Consume an outcome with owned native handlers and their exact shared error type."""
    return fold_outcome(outcome^, NativeUnary[A, R, X, F, True](on_success^), NativeUnary[B, R, X, G, True](on_failure^), _NativeThunk[R, X, H, True](on_cancel^))


@fieldwise_init
struct ExitCase[E: Movable & Deinitable](Movable):
    """An exit observed by a finalizer, preserving exact move-only failures.

    Finalizers borrow this value. Failure and cancellation can both be true;
    errors retain execution order. Success payloads remain owned by the runner.

    Parameters:
        E: The exact native error type.
    """
    var _failure: Optional[EffectFailure[Self.E]]
    var _canceled: Bool

    def is_success(self) -> Bool:
        """Return whether the protected operation succeeded.

        Returns:
            True only for a successful, uncanceled operation.
        """
        return not self._failure and not self._canceled

    def is_error(self) -> Bool:
        """Return whether the protected operation retained any failures.

        Returns:
            True when at least one exact error is available.
        """
        return Bool(self._failure)

    def is_canceled(self) -> Bool:
        """Return whether cancellation was observed, including failed cleanup.

        Returns:
            True when the protected operation also observed cancellation.
        """
        return self._canceled

    def failure(ref self) -> ref[self._failure] Optional[EffectFailure[Self.E]]:
        """Borrow the optional exact failure without copying or consuming it.

        Returns:
            The optional failure, borrowed from this exit case.
        """
        return self._failure


struct _ExitState[T: Movable & Deinitable, E: Movable & Deinitable](Movable):
    var value: Optional[Self.T]
    var exit: ExitCase[Self.E]

    def __init__(out self, var outcome: Outcome[Self.T, Self.E]):
        self.value = None
        self.exit = ExitCase[Self.E](None, not outcome)
        if outcome:
            var result = outcome.take()
            if result.is_err():
                var failure = result^._take_err()
                self.exit._canceled = failure.canceled
                self.exit._failure = Optional(failure^)
            else:
                self.value = Optional(result^._take_ok())

    def outcome(deinit self) -> Outcome[Self.T, Self.E]:
        if self.exit._failure:
            return Optional(Result[Self.T, EffectFailure[Self.E]](Err(self.exit._failure.take())))
        if self.exit._canceled:
            return None
        return Optional(Result[Self.T, EffectFailure[Self.E]](Ok(self.value.take())))


def _capture[E: Movable & Deinitable, F: OnceThunk](var function: F
) -> Result[F.Out, EffectFailure[E]] where _ErrorCompatible[E, F.Error]:
    var captured = attempt_once(function^)
    if captured.is_ok():
        return Ok(captured^._take_ok())
    comptime if F.Error == Never:
        var impossible = captured^._take_err()
        return _absurd[Result[F.Out, EffectFailure[E]]](rebind[Never](impossible))
    else:
        return Err(EffectFailure[E](NonEmptyList(rebind_var[E](captured^._take_err())), False))


def _discard[T: Movable & Deinitable, E: Movable & Deinitable](
    var result: Result[T, EffectFailure[E]]
) -> Result[NoneType, EffectFailure[E]]:
    if result.is_err():
        return Err(result^._take_err())
    var unit: NoneType = None
    return Ok(unit)


def _finish[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](
    var body: Outcome[T, E], var cleanup: Outcome[U, E]
) -> Outcome[T, E]:
    """Combine completed outcomes; callers own when and how finalizers execute."""
    if cleanup:
        var released = cleanup.take()
        if released.is_ok():
            return body^
        var failure = released^._take_err()
        if not body:
            failure.canceled = True
        else:
            var used = body.take()
            if used.is_err():
                var primary = used^._take_err()
                var canceled = primary.canceled or failure.canceled
                var primary_errors = primary^.into_errors()
                var cleanup_errors = failure^.into_errors()
                var errors = primary_errors^.into_list()
                errors.extend(cleanup_errors^.into_list())
                var combined = NonEmptyList[E].from_list(errors^)
                return Optional(Result[T, EffectFailure[E]](Err(EffectFailure[E](combined.take(), canceled))))
        return Optional(Result[T, EffectFailure[E]](Err(failure^)))
    if body:
        var used = body.take()
        if used.is_err():
            var failure = used^._take_err()
            failure.canceled = True
            return Optional(Result[T, EffectFailure[E]](Err(failure^)))
    return None


def _failure_as[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](var failure: Outcome[U, E]) -> Outcome[T, E]:
    """Retype an already-checked unsuccessful outcome without losing errors."""
    if not failure:
        return None
    var result = failure.take()
    return Optional(Result[T, EffectFailure[E]](Err(result^._take_err())))


def _zip_outcomes[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](
    var left: Outcome[T, E], var right: Outcome[U, E]
) -> Outcome[Tuple[T, U], E]:
    """Keep both successes; delegate all unsuccessful merging to _finish."""
    if left and right and left.value().is_ok() and right.value().is_ok():
        return Optional(Result[Tuple[T, U], EffectFailure[E]](Ok((left.take()._take_ok(), right.take()._take_ok()))))
    return _failure_as[Tuple[T, U]](_finish(left^, right^))


def _finish_native[T: Movable & Deinitable, U: Movable & Deinitable, E: Movable & Deinitable](
    var body: Result[T, EffectFailure[E]], var cleanup: Result[U, EffectFailure[E]]
) -> Result[T, EffectFailure[E]]:
    var result = _finish(Optional(body^), Optional(cleanup^))
    # Neither input can be cancellation, so finalization is guaranteed present.
    return result.take()
