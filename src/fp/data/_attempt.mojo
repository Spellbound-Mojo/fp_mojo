"""One-shot capture of a library thunk's outcome; Capture owns the public entry points.

`Capture.run(thunk)` and every bound native call delegate here: the thunk is
consumed, called once through `call_once`, and its declared error is stored in
`Err`. Argument bundles and Result storage have separate owners.
"""
from ._result import Result, Ok, Err
from fp.callables.protocols import ThunkContract
from fp.callables.invoke import call_once, _OnceThunkAvailable


def _attempt_once[F: ThunkContract & Movable & Deinitable](var function: F) -> Result[F.Out, F.Error]:
    """Consume a library thunk, invoke it once and capture its outcome.

    `call_once` selects its consuming receiver, then mutable, then shared.
    Receiver state, results and errors may be move-only; owned state is
    destroyed on every path. Pass `mut_ref(thunk)` to retain the original
    state for reuse or inspection, including after a captured failure.
    References in the result or error must belong to owners that outlive the
    consumed thunk.

    Parameters:
        F: A ThunkContract with a shared, mutable or consuming receiver.

    Args:
        function: The thunk, consumed.

    Returns:
        `Ok(result)`, or `Err(error)` for its declared error.
    """
    comptime assert _OnceThunkAvailable[F], "Capture.run: thunk implements no receiver mode"
    var pending = Optional(function^)
    var context = Pointer(to=pending)
    return _attempt_core[F.Out, F.Error, type_of(context),
        _attempt_consuming[F, origin_of(pending)]](context)


def _attempt_core[R: Movable & Deinitable, E: Movable & Deinitable, C: AnyType,
                  apply: def(C) raises E capturing -> R](context: C) -> Result[R,E]:
    try:
        return Result[R,E](Ok(apply(context)))
    except error:
        return Result[R,E](Err(error^))


def _attempt_consuming[F: ThunkContract & Movable & Deinitable, origin: MutOrigin](
    context: Pointer[Optional[F], origin]
) raises F.Error capturing -> F.Out:
    # _attempt_core borrows its native context; this boundary moves the pending
    # owner into call_once. Result/error conversion stays shared.
    var function = context[].take()
    return call_once(function^)
