"""Native capture front ends; argument bundles and Result storage have separate owners."""
from ._result import Result, Ok, Err
from fp.callables.protocols import OnceThunk
from fp.callables.native import (_NativeUnaryRef, _NativeMutatingRef, _NativeMutOwnedRef, _NativeMutOwnedKeywordsRef)
from fp.callables._binding import _BoundThunk
from fp.callables._arguments import _ArgumentsZ, _invoke_Z, _ArgumentsK, _invoke_K, _ArgumentsR, _invoke_R, _ArgumentsRK, _invoke_RK, _ArgumentsM, _invoke_M, _ArgumentsMK, _invoke_MK, _ArgumentsO, _invoke_O, _ArgumentsOK, _invoke_OK, _ArgumentsRR, _invoke_RR, _ArgumentsRRK, _invoke_RRK, _ArgumentsRM, _invoke_RM, _ArgumentsRMK, _invoke_RMK, _ArgumentsRO, _invoke_RO, _ArgumentsROK, _invoke_ROK, _ArgumentsMR, _invoke_MR, _ArgumentsMRK, _invoke_MRK, _ArgumentsMM, _invoke_MM, _ArgumentsMMK, _invoke_MMK, _ArgumentsMO, _invoke_MO, _ArgumentsMOK, _invoke_MOK, _ArgumentsOR, _invoke_OR, _ArgumentsORK, _invoke_ORK, _ArgumentsOM, _invoke_OM, _ArgumentsOMK, _invoke_OMK, _ArgumentsOO, _invoke_OO, _ArgumentsOOK, _invoke_OOK

# Each native convention family owns a distinct optional parameter name.
# Binding it excludes incompatible families before Mojo 1.2 infers native
# callback operands. Keep selectors after existing parameters to retain F
# and fallback parameter positions; the where clause rejects False.
def attempt[T: Movable & Deinitable, //, F: def() -> T, zero: Bool = True](function: F) -> Result[T, Never] where zero:
    """Call `function` once and capture its outcome: `Ok(result)`, or `Err(error)` for its declared error.

    Overloads take zero, one or two positional arguments with their native read,
    `var` or `mut` conventions. Use `attempt_kwargs` for a callback with a
    native keyword pack, including an empty pack. Pass consumed arguments
    with `^`. Changes made through a `mut`
    argument before a failure remain visible. Every declared positional
    parameter must be supplied, including defaulted ones; other call shapes
    are written as a closure passed to the zero-argument form.

    On Mojo 1.2, an optional named convention selector avoids incompatible
    overload inference: `attempt[owned=True](function, value^)` or
    `attempt[owned_mut=True](function, value^, state)`. Unary selectors are
    `read`, `owned` and `mutable`; binary names combine `read`, `owned`
    and `mut` in argument order. A default scalar uses the owned family.
    Selectors must be True and leave existing positional type bindings
    unchanged. The borrowed `mutating`, `consuming` and `mut_owned`
    adapters remain supported. For a diagnostic on an incompatible
    selector, also bind `F=type_of(function)`; without this hint, Mojo 1.2
    can crash before rejecting the callback.

    The function is borrowed and reusable. A returned `Result` is ordinary
    success data, and a declared `StopIteration` is captured like any other
    error; process aborts are never caught.

    Parameters:
        T: The result type.
        F: The function's type: a plain function or a closure.
        zero: Select the zero-positional-argument convention; must be True.

    Args:
        function: The function, borrowed; it runs once.

    Returns:
        `Ok(result)`; a pure function never produces `Err`, so the error type
        is `Never`.
    """
    var arguments = _ArgumentsZ()
    return attempt_once(_BoundThunk[_ArgumentsZ, T, Never, F, origin_of(function), _invoke_Z[T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def() raises E -> T, zero: Bool = True](function: F) -> Result[T, E] where zero:
    """Call once and retain the exact native error as an Err payload."""
    var arguments = _ArgumentsZ()
    return attempt_once(_BoundThunk[_ArgumentsZ, T, E, F, origin_of(function), _invoke_Z[T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A) -> T, read: Bool = True](
    function: F, first: A
) -> Result[T, Never] where read and not conforms_to(A, TrivialRegisterPassable):
    """Capture a pure call once; its error channel is Never."""
    var arguments = _ArgumentsR[A, origin_of(first)](Pointer(to=first))
    return attempt_once(_BoundThunk[_ArgumentsR[A, origin_of(first)], T, Never, F, origin_of(function), _invoke_R[A, origin_of(first), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A) raises E -> T, read: Bool = True](
    function: F, first: A
) -> Result[T, E] where read and not conforms_to(A, TrivialRegisterPassable):
    """Invoke once with native argument conventions and retain the exact typed error."""
    var arguments = _ArgumentsR[A, origin_of(first)](Pointer(to=first))
    return attempt_once(_BoundThunk[_ArgumentsR[A, origin_of(first)], T, E, F, origin_of(function), _invoke_R[A, origin_of(first), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A) -> T, owned: Bool = True](
    function: F, var first: A
) -> Result[T, Never] where owned:
    """Capture a pure call once; its error channel is Never."""
    var arguments = _ArgumentsO[A](first^)
    return attempt_once(_BoundThunk[_ArgumentsO[A], T, Never, F, origin_of(function), _invoke_O[A, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A) raises E -> T, owned: Bool = True](
    function: F, var first: A
) -> Result[T, E] where owned:
    """Invoke once with native argument conventions and retain the exact typed error."""
    var arguments = _ArgumentsO[A](first^)
    return attempt_once(_BoundThunk[_ArgumentsO[A], T, E, F, origin_of(function), _invoke_O[A, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, B) -> T, read_read: Bool = True](
    function: F, first: A, second: B
) -> Result[T, Never] where read_read and not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    """Capture a pure call once; its error channel is Never."""
    var arguments = _ArgumentsRR[A, B, origin_of(first), origin_of(second)](Pointer(to=first), Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsRR[A, B, origin_of(first), origin_of(second)], T, Never, F, origin_of(function), _invoke_RR[A, B, origin_of(first), origin_of(second), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, B) raises E -> T, read_read: Bool = True](
    function: F, first: A, second: B
) -> Result[T, E] where read_read and not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    """Invoke once with native argument conventions and retain the exact typed error."""
    var arguments = _ArgumentsRR[A, B, origin_of(first), origin_of(second)](Pointer(to=first), Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsRR[A, B, origin_of(first), origin_of(second)], T, E, F, origin_of(function), _invoke_RR[A, B, origin_of(first), origin_of(second), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, B) -> T, owned_read: Bool = True](
    function: F, var first: A, second: B
) -> Result[T, Never] where owned_read and not conforms_to(B, TrivialRegisterPassable):
    """Capture a pure call once; its error channel is Never."""
    var arguments = _ArgumentsOR[A, B, origin_of(second)](first^, Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsOR[A, B, origin_of(second)], T, Never, F, origin_of(function), _invoke_OR[A, B, origin_of(second), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, B) raises E -> T, owned_read: Bool = True](
    function: F, var first: A, second: B
) -> Result[T, E] where owned_read and not conforms_to(B, TrivialRegisterPassable):
    """Invoke once with native argument conventions and retain the exact typed error."""
    var arguments = _ArgumentsOR[A, B, origin_of(second)](first^, Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsOR[A, B, origin_of(second)], T, E, F, origin_of(function), _invoke_OR[A, B, origin_of(second), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, var B) -> T, read_owned: Bool = True](
    function: F, first: A, var second: B
) -> Result[T, Never] where read_owned and not conforms_to(A, TrivialRegisterPassable):
    """Capture a pure call once; its error channel is Never."""
    var arguments = _ArgumentsRO[A, B, origin_of(first)](Pointer(to=first), second^)
    return attempt_once(_BoundThunk[_ArgumentsRO[A, B, origin_of(first)], T, Never, F, origin_of(function), _invoke_RO[A, B, origin_of(first), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, var B) raises E -> T, read_owned: Bool = True](
    function: F, first: A, var second: B
) -> Result[T, E] where read_owned and not conforms_to(A, TrivialRegisterPassable):
    """Invoke once with native argument conventions and retain the exact typed error."""
    var arguments = _ArgumentsRO[A, B, origin_of(first)](Pointer(to=first), second^)
    return attempt_once(_BoundThunk[_ArgumentsRO[A, B, origin_of(first)], T, E, F, origin_of(function), _invoke_RO[A, B, origin_of(first), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, var B) -> T, owned_owned: Bool = True](
    function: F, var first: A, var second: B
) -> Result[T, Never] where owned_owned:
    """Capture a pure call once; its error channel is Never."""
    var arguments = _ArgumentsOO[A, B](first^, second^)
    return attempt_once(_BoundThunk[_ArgumentsOO[A, B], T, Never, F, origin_of(function), _invoke_OO[A, B, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, var B) raises E -> T, owned_owned: Bool = True](
    function: F, var first: A, var second: B
) -> Result[T, E] where owned_owned:
    """Invoke once with native argument conventions and retain the exact typed error."""
    var arguments = _ArgumentsOO[A, B](first^, second^)
    return attempt_once(_BoundThunk[_ArgumentsOO[A, B], T, E, F, origin_of(function), _invoke_OO[A, B, T, E, F, True]](arguments^, Pointer(to=function)))


# Native keyword packs are owned homogeneous dictionaries. Fixed prefixes keep
# their native argument conventions; all bridge arguments are positional-only.
# Keep these overloads separate from attempt: Mojo 1.2 crashes while inferring
# the error type of an incompatible positional/keyword callback candidate.
def attempt_kwargs[K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var **kwargs: K) -> T, zero: Bool = True](
    function: F, /, var **values: K
) -> Result[T, Never] where zero:
    """Call once with a native keyword pack and capture its outcome as a Result.

    The callback must declare `var **kwargs: K`, optionally after zero, one
    or two positional parameters with read, `var` or `mut` conventions. Pass
    the callback and its positional arguments positionally, and pass consumed
    arguments with `^`. Keyword values are homogeneous and owned; a
    `StringDict[K]` can be expanded with `**options^`. An empty pack still uses
    `attempt_kwargs(function)`. Optional named convention selectors match
    `attempt` and describe only the positional prefix, for example
    `attempt_kwargs[mutable=True](function, state, key=value)`. Use
    `zero=True` for no positional prefix. Selectors must be True. The
    `mut_owned_kwargs` adapter remains supported. For an incompatible
    selector diagnostic, also bind `F=type_of(function)`.

    The callback is borrowed and reusable. Mutation before failure remains
    visible; its exact declared error, including `StopIteration`, is stored
    as `Err`. A returned Result is ordinary success data. Every positional
    parameter must be supplied, including defaulted ones. Named parameters
    without a native keyword pack require a closure passed to `attempt`.

    Parameters:
        K: The owned keyword value type.
        T: The result type.
        F: The function's type: a plain function or a closure.
        zero: Select the zero-positional-argument convention; must be True.

    Args:
        function: The borrowed function, invoked once.
        values: The owned keyword values forwarded to the callback.

    Returns:
        The successful value as `Ok`, or the exact declared error as `Err`;
        a non-raising callback has error type `Never`.
    """
    var arguments = _ArgumentsK[K](values^)
    return attempt_once(_BoundThunk[_ArgumentsK[K], T, Never, F, origin_of(function), _invoke_K[K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var **kwargs: K) raises E -> T, zero: Bool = True](
    function: F, /, var **values: K
) -> Result[T, E] where zero:
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsK[K](values^)
    return attempt_once(_BoundThunk[_ArgumentsK[K], T, E, F, origin_of(function), _invoke_K[K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, /, var **kwargs: K) -> T, read: Bool = True](
    function: F, first: A, /, var **values: K
) -> Result[T, Never] where read and not conforms_to(A, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsRK[A, origin_of(first), K](Pointer(to=first), values^)
    return attempt_once(_BoundThunk[_ArgumentsRK[A, origin_of(first), K], T, Never, F, origin_of(function), _invoke_RK[A, origin_of(first), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, /, var **kwargs: K) raises E -> T, read: Bool = True](
    function: F, first: A, /, var **values: K
) -> Result[T, E] where read and not conforms_to(A, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsRK[A, origin_of(first), K](Pointer(to=first), values^)
    return attempt_once(_BoundThunk[_ArgumentsRK[A, origin_of(first), K], T, E, F, origin_of(function), _invoke_RK[A, origin_of(first), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, /, var **kwargs: K) -> T, owned: Bool = True](
    function: F, var first: A, /, var **values: K
) -> Result[T, Never] where owned:
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsOK[A, K](first^, values^)
    return attempt_once(_BoundThunk[_ArgumentsOK[A, K], T, Never, F, origin_of(function), _invoke_OK[A, K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, /, var **kwargs: K) raises E -> T, owned: Bool = True](
    function: F, var first: A, /, var **values: K
) -> Result[T, E] where owned:
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsOK[A, K](first^, values^)
    return attempt_once(_BoundThunk[_ArgumentsOK[A, K], T, E, F, origin_of(function), _invoke_OK[A, K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, B, /, var **kwargs: K) -> T, read_read: Bool = True](
    function: F, first: A, second: B, /, var **values: K
) -> Result[T, Never] where read_read and not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsRRK[A, B, origin_of(first), origin_of(second), K](Pointer(to=first), Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsRRK[A, B, origin_of(first), origin_of(second), K], T, Never, F, origin_of(function), _invoke_RRK[A, B, origin_of(first), origin_of(second), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, B, /, var **kwargs: K) raises E -> T, read_read: Bool = True](
    function: F, first: A, second: B, /, var **values: K
) -> Result[T, E] where read_read and not conforms_to(A, TrivialRegisterPassable) and not conforms_to(B, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsRRK[A, B, origin_of(first), origin_of(second), K](Pointer(to=first), Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsRRK[A, B, origin_of(first), origin_of(second), K], T, E, F, origin_of(function), _invoke_RRK[A, B, origin_of(first), origin_of(second), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, B, /, var **kwargs: K) -> T, owned_read: Bool = True](
    function: F, var first: A, second: B, /, var **values: K
) -> Result[T, Never] where owned_read and not conforms_to(B, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsORK[A, B, origin_of(second), K](first^, Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsORK[A, B, origin_of(second), K], T, Never, F, origin_of(function), _invoke_ORK[A, B, origin_of(second), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, B, /, var **kwargs: K) raises E -> T, owned_read: Bool = True](
    function: F, var first: A, second: B, /, var **values: K
) -> Result[T, E] where owned_read and not conforms_to(B, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsORK[A, B, origin_of(second), K](first^, Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsORK[A, B, origin_of(second), K], T, E, F, origin_of(function), _invoke_ORK[A, B, origin_of(second), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, var B, /, var **kwargs: K) -> T, read_owned: Bool = True](
    function: F, first: A, var second: B, /, var **values: K
) -> Result[T, Never] where read_owned and not conforms_to(A, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsROK[A, B, origin_of(first), K](Pointer(to=first), second^, values^)
    return attempt_once(_BoundThunk[_ArgumentsROK[A, B, origin_of(first), K], T, Never, F, origin_of(function), _invoke_ROK[A, B, origin_of(first), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, var B, /, var **kwargs: K) raises E -> T, read_owned: Bool = True](
    function: F, first: A, var second: B, /, var **values: K
) -> Result[T, E] where read_owned and not conforms_to(A, TrivialRegisterPassable):
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsROK[A, B, origin_of(first), K](Pointer(to=first), second^, values^)
    return attempt_once(_BoundThunk[_ArgumentsROK[A, B, origin_of(first), K], T, E, F, origin_of(function), _invoke_ROK[A, B, origin_of(first), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, var B, /, var **kwargs: K) -> T, owned_owned: Bool = True](
    function: F, var first: A, var second: B, /, var **values: K
) -> Result[T, Never] where owned_owned:
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsOOK[A, B, K](first^, second^, values^)
    return attempt_once(_BoundThunk[_ArgumentsOOK[A, B, K], T, Never, F, origin_of(function), _invoke_OOK[A, B, K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, var B, /, var **kwargs: K) raises E -> T, owned_owned: Bool = True](
    function: F, var first: A, var second: B, /, var **values: K
) -> Result[T, E] where owned_owned:
    """Forward native keyword values once; preserve the selected native error channel."""
    var arguments = _ArgumentsOOK[A, B, K](first^, second^, values^)
    return attempt_once(_BoundThunk[_ArgumentsOOK[A, B, K], T, E, F, origin_of(function), _invoke_OOK[A, B, K, T, E, F, True]](arguments^, Pointer(to=function)))


# Mutable prefixes retain exclusive native borrows on success and failure.
# Mojo 1.2 admits read callbacks to these signatures without a conversion
# penalty. One defaulted parameter per mutable argument makes a read overload
# win otherwise equal candidates (OverloadFitness prefers fewer bindings).
# Keep these parameters after F so existing explicit callback bindings retain
# their positions. Their values are unused; callers need not supply them.
# Pure/raising pairs remain separate: inferring E=Never can lose the native
# closure witness at invocation, and incompatible conventions can still crash
# during inference, before this ranking is considered.
def attempt[A: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A) -> T, _mut_fallback_0: Int = 0, mutable: Bool = True](
    function: F, mut first: A
) -> Result[T, Never] where mutable:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsM[A, origin_of(first)](Pointer(to=first))
    return attempt_once(_BoundThunk[_ArgumentsM[A, origin_of(first)], T, Never, F, origin_of(function), _invoke_M[A, origin_of(first), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A) raises E -> T, _mut_fallback_0: Int = 0, mutable: Bool = True](
    function: F, mut first: A
) -> Result[T, E] where mutable:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsM[A, origin_of(first)](Pointer(to=first))
    return attempt_once(_BoundThunk[_ArgumentsM[A, origin_of(first)], T, E, F, origin_of(function), _invoke_M[A, origin_of(first), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, mut B) -> T, _mut_fallback_0: Int = 0, read_mut: Bool = True](
    function: F, first: A, mut second: B
) -> Result[T, Never] where read_mut and not conforms_to(A, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsRM[A, B, origin_of(first), origin_of(second)](Pointer(to=first), Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsRM[A, B, origin_of(first), origin_of(second)], T, Never, F, origin_of(function), _invoke_RM[A, B, origin_of(first), origin_of(second), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, mut B) raises E -> T, _mut_fallback_0: Int = 0, read_mut: Bool = True](
    function: F, first: A, mut second: B
) -> Result[T, E] where read_mut and not conforms_to(A, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsRM[A, B, origin_of(first), origin_of(second)](Pointer(to=first), Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsRM[A, B, origin_of(first), origin_of(second)], T, E, F, origin_of(function), _invoke_RM[A, B, origin_of(first), origin_of(second), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, mut B) -> T, _mut_fallback_0: Int = 0, owned_mut: Bool = True](
    function: F, var first: A, mut second: B
) -> Result[T, Never] where owned_mut:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsOM[A, B, origin_of(second)](first^, Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsOM[A, B, origin_of(second)], T, Never, F, origin_of(function), _invoke_OM[A, B, origin_of(second), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, mut B) raises E -> T, _mut_fallback_0: Int = 0, owned_mut: Bool = True](
    function: F, var first: A, mut second: B
) -> Result[T, E] where owned_mut:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsOM[A, B, origin_of(second)](first^, Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsOM[A, B, origin_of(second)], T, E, F, origin_of(function), _invoke_OM[A, B, origin_of(second), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, B) -> T, _mut_fallback_0: Int = 0, mut_read: Bool = True](
    function: F, mut first: A, second: B
) -> Result[T, Never] where mut_read and not conforms_to(B, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMR[A, B, origin_of(first), origin_of(second)](Pointer(to=first), Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsMR[A, B, origin_of(first), origin_of(second)], T, Never, F, origin_of(function), _invoke_MR[A, B, origin_of(first), origin_of(second), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, B) raises E -> T, _mut_fallback_0: Int = 0, mut_read: Bool = True](
    function: F, mut first: A, second: B
) -> Result[T, E] where mut_read and not conforms_to(B, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMR[A, B, origin_of(first), origin_of(second)](Pointer(to=first), Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsMR[A, B, origin_of(first), origin_of(second)], T, E, F, origin_of(function), _invoke_MR[A, B, origin_of(first), origin_of(second), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, var B) -> T, _mut_fallback_0: Int = 0, mut_owned: Bool = True](
    function: F, mut first: A, var second: B
) -> Result[T, Never] where mut_owned:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMO[A, B, origin_of(first)](Pointer(to=first), second^)
    return attempt_once(_BoundThunk[_ArgumentsMO[A, B, origin_of(first)], T, Never, F, origin_of(function), _invoke_MO[A, B, origin_of(first), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, var B) raises E -> T, _mut_fallback_0: Int = 0, mut_owned: Bool = True](
    function: F, mut first: A, var second: B
) -> Result[T, E] where mut_owned:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMO[A, B, origin_of(first)](Pointer(to=first), second^)
    return attempt_once(_BoundThunk[_ArgumentsMO[A, B, origin_of(first)], T, E, F, origin_of(function), _invoke_MO[A, B, origin_of(first), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, mut B) -> T, _mut_fallback_0: Int = 0, _mut_fallback_1: Int = 0, mut_mut: Bool = True](
    function: F, mut first: A, mut second: B
) -> Result[T, Never] where mut_mut:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMM[A, B, origin_of(first), origin_of(second)](Pointer(to=first), Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsMM[A, B, origin_of(first), origin_of(second)], T, Never, F, origin_of(function), _invoke_MM[A, B, origin_of(first), origin_of(second), T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, mut B) raises E -> T, _mut_fallback_0: Int = 0, _mut_fallback_1: Int = 0, mut_mut: Bool = True](
    function: F, mut first: A, mut second: B
) -> Result[T, E] where mut_mut:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMM[A, B, origin_of(first), origin_of(second)](Pointer(to=first), Pointer(to=second))
    return attempt_once(_BoundThunk[_ArgumentsMM[A, B, origin_of(first), origin_of(second)], T, E, F, origin_of(function), _invoke_MM[A, B, origin_of(first), origin_of(second), T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, /, var **kwargs: K) -> T, _mut_fallback_0: Int = 0, mutable: Bool = True](
    function: F, mut first: A, /, var **values: K
) -> Result[T, Never] where mutable:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMK[A, origin_of(first), K](Pointer(to=first), values^)
    return attempt_once(_BoundThunk[_ArgumentsMK[A, origin_of(first), K], T, Never, F, origin_of(function), _invoke_MK[A, origin_of(first), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, /, var **kwargs: K) raises E -> T, _mut_fallback_0: Int = 0, mutable: Bool = True](
    function: F, mut first: A, /, var **values: K
) -> Result[T, E] where mutable:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMK[A, origin_of(first), K](Pointer(to=first), values^)
    return attempt_once(_BoundThunk[_ArgumentsMK[A, origin_of(first), K], T, E, F, origin_of(function), _invoke_MK[A, origin_of(first), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(A, mut B, /, var **kwargs: K) -> T, _mut_fallback_0: Int = 0, read_mut: Bool = True](
    function: F, first: A, mut second: B, /, var **values: K
) -> Result[T, Never] where read_mut and not conforms_to(A, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsRMK[A, B, origin_of(first), origin_of(second), K](Pointer(to=first), Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsRMK[A, B, origin_of(first), origin_of(second), K], T, Never, F, origin_of(function), _invoke_RMK[A, B, origin_of(first), origin_of(second), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(A, mut B, /, var **kwargs: K) raises E -> T, _mut_fallback_0: Int = 0, read_mut: Bool = True](
    function: F, first: A, mut second: B, /, var **values: K
) -> Result[T, E] where read_mut and not conforms_to(A, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsRMK[A, B, origin_of(first), origin_of(second), K](Pointer(to=first), Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsRMK[A, B, origin_of(first), origin_of(second), K], T, E, F, origin_of(function), _invoke_RMK[A, B, origin_of(first), origin_of(second), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(var A, mut B, /, var **kwargs: K) -> T, _mut_fallback_0: Int = 0, owned_mut: Bool = True](
    function: F, var first: A, mut second: B, /, var **values: K
) -> Result[T, Never] where owned_mut:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsOMK[A, B, origin_of(second), K](first^, Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsOMK[A, B, origin_of(second), K], T, Never, F, origin_of(function), _invoke_OMK[A, B, origin_of(second), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(var A, mut B, /, var **kwargs: K) raises E -> T, _mut_fallback_0: Int = 0, owned_mut: Bool = True](
    function: F, var first: A, mut second: B, /, var **values: K
) -> Result[T, E] where owned_mut:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsOMK[A, B, origin_of(second), K](first^, Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsOMK[A, B, origin_of(second), K], T, E, F, origin_of(function), _invoke_OMK[A, B, origin_of(second), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, B, /, var **kwargs: K) -> T, _mut_fallback_0: Int = 0, mut_read: Bool = True](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[T, Never] where mut_read and not conforms_to(B, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMRK[A, B, origin_of(first), origin_of(second), K](Pointer(to=first), Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsMRK[A, B, origin_of(first), origin_of(second), K], T, Never, F, origin_of(function), _invoke_MRK[A, B, origin_of(first), origin_of(second), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, B, /, var **kwargs: K) raises E -> T, _mut_fallback_0: Int = 0, mut_read: Bool = True](
    function: F, mut first: A, second: B, /, var **values: K
) -> Result[T, E] where mut_read and not conforms_to(B, TrivialRegisterPassable):
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMRK[A, B, origin_of(first), origin_of(second), K](Pointer(to=first), Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsMRK[A, B, origin_of(first), origin_of(second), K], T, E, F, origin_of(function), _invoke_MRK[A, B, origin_of(first), origin_of(second), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, var B, /, var **kwargs: K) -> T, _mut_fallback_0: Int = 0, mut_owned: Bool = True](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[T, Never] where mut_owned:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMOK[A, B, origin_of(first), K](Pointer(to=first), second^, values^)
    return attempt_once(_BoundThunk[_ArgumentsMOK[A, B, origin_of(first), K], T, Never, F, origin_of(function), _invoke_MOK[A, B, origin_of(first), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, var B, /, var **kwargs: K) raises E -> T, _mut_fallback_0: Int = 0, mut_owned: Bool = True](
    function: F, mut first: A, var second: B, /, var **values: K
) -> Result[T, E] where mut_owned:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMOK[A, B, origin_of(first), K](Pointer(to=first), second^, values^)
    return attempt_once(_BoundThunk[_ArgumentsMOK[A, B, origin_of(first), K], T, E, F, origin_of(function), _invoke_MOK[A, B, origin_of(first), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, //,
            F: def(mut A, mut B, /, var **kwargs: K) -> T, _mut_fallback_0: Int = 0, _mut_fallback_1: Int = 0, mut_mut: Bool = True](
    function: F, mut first: A, mut second: B, /, var **values: K
) -> Result[T, Never] where mut_mut:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMMK[A, B, origin_of(first), origin_of(second), K](Pointer(to=first), Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsMMK[A, B, origin_of(first), origin_of(second), K], T, Never, F, origin_of(function), _invoke_MMK[A, B, origin_of(first), origin_of(second), K, T, Never, F, False]](arguments^, Pointer(to=function)))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable, T: Movable & Deinitable, E: Movable & Deinitable, //,
            F: def(mut A, mut B, /, var **kwargs: K) raises E -> T, _mut_fallback_0: Int = 0, _mut_fallback_1: Int = 0, mut_mut: Bool = True](
    function: F, mut first: A, mut second: B, /, var **values: K
) -> Result[T, E] where mut_mut:
    """Forward once, preserving caller mutation and the exact native error channel."""
    var arguments = _ArgumentsMMK[A, B, origin_of(first), origin_of(second), K](Pointer(to=first), Pointer(to=second), values^)
    return attempt_once(_BoundThunk[_ArgumentsMMK[A, B, origin_of(first), origin_of(second), K], T, E, F, origin_of(function), _invoke_MMK[A, B, origin_of(first), origin_of(second), K, T, E, F, True]](arguments^, Pointer(to=function)))


def attempt_once[F: OnceThunk](var function: F) -> Result[F.Out, F.Error]:
    """Consume a `OnceThunk`, call it once and capture its outcome.

    Receiver state, results and errors may be move-only; unused state is
    destroyed on every path. References in the result or error must belong to
    owners that outlive the thunk.

    Parameters:
        F: The thunk's type.

    Args:
        function: The thunk, consumed.

    Returns:
        `Ok(result)`, or `Err(error)` for its declared error.
    """
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


def _attempt_consuming[F: OnceThunk, origin: MutOrigin](
    context: Pointer[Optional[F], origin]
) raises F.Error capturing -> F.Out:
    # _attempt_core borrows its native context; this boundary moves the pending
    # owner into call_once. Result/error conversion stays shared.
    var function = context[].take()
    return function^.call_once()


# Convention adapters retain the original callback pointer. Both these calls
# and Capture transfer a native argument bundle through the same _BoundThunk;
# attempt_once and _attempt_core own one-shot execution and Result capture.
def mutating[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
             F: def(mut A) -> R](ref[o] function: F) -> _NativeMutatingRef[A, R, Never, F, False, o]:
    """Borrow a native callback taking one mutable argument for `attempt`.

    Use `attempt(mutating(function), value)`. Mutation remains visible even
    when the callback raises.

    This borrows the callback without invoking or copying it. Keep the callback
    alive while the adapter is used. Pure callbacks produce a `Never` error
    channel; raising callbacks retain their exact declared error type.
    Select the adapter matching the callback convention: incompatible factory
    calls can crash the Mojo 1.2 compiler instead of producing a diagnostic.

    Parameters:
        A: The mutable argument type.
        R: The result type.
        o: The borrowed callback origin, inferred.
        F: The exact native function or closure type.

    Args:
        function: The native callback, borrowed with its captures and origin.

    Returns:
        A reusable borrowed adapter for a mutable argument.
    """
    return _NativeMutatingRef[A, R, Never, F, False, o](Pointer(to=function))


def mutating[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //,
             F: def(mut A) raises E -> R](ref[o] function: F) -> _NativeMutatingRef[A, R, E, F, True, o]:
    """Borrow a raising native callback, retaining its exact error type."""
    return _NativeMutatingRef[A, R, E, F, True, o](Pointer(to=function))


def consuming[A: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
              F: def(var A) -> R](ref[o] function: F) -> _NativeUnaryRef[A, R, Never, F, False, o]:
    """Borrow a native callback taking one owned argument for `attempt`.

    Use `attempt(consuming(function), value^)`. Only the argument is consumed;
    the callback remains reusable.

    This borrows the callback without invoking or copying it. Keep the callback
    alive while the adapter is used. Pure callbacks produce a `Never` error
    channel; raising callbacks retain their exact declared error type.
    Select the adapter matching the callback convention: incompatible factory
    calls can crash the Mojo 1.2 compiler instead of producing a diagnostic.

    Parameters:
        A: The owned argument type.
        R: The result type.
        o: The borrowed callback origin, inferred.
        F: The exact native function or closure type.

    Args:
        function: The native callback, borrowed with its captures and origin.

    Returns:
        A reusable borrowed adapter for an owned argument.
    """
    return _NativeUnaryRef[A, R, Never, F, False, o](Pointer(to=function))


def consuming[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //,
              F: def(var A) raises E -> R](ref[o] function: F) -> _NativeUnaryRef[A, R, E, F, True, o]:
    """Borrow a raising native callback, retaining its exact error type."""
    return _NativeUnaryRef[A, R, E, F, True, o](Pointer(to=function))


def attempt[A: Movable & Deinitable, R: Movable & Deinitable,
            E: Movable & Deinitable, F: Movable & Deinitable,
            raising: Bool, o: ImmOrigin, q: MutOrigin](
    function: _NativeMutatingRef[A, R, E, F, raising, o], ref[q] value: A
) -> Result[R, E]:
    """Call the borrowed convention adapter once and capture its exact outcome."""
    var arguments = _ArgumentsM[A, origin_of(value)](Pointer(to=value))
    return attempt_once(_BoundThunk[_ArgumentsM[A, origin_of(value)], R, E, F, o, _invoke_M[A, origin_of(value), R, E, F, raising]](arguments^, function.function))


def attempt[A: Movable & Deinitable, R: Movable & Deinitable,
            E: Movable & Deinitable, F: Movable & Deinitable,
            raising: Bool, o: ImmOrigin](
    function: _NativeUnaryRef[A, R, E, F, raising, o], var value: A
) -> Result[R, E]:
    """Call the borrowed convention adapter once and capture its exact outcome."""
    var arguments = _ArgumentsO[A](value^)
    return attempt_once(_BoundThunk[_ArgumentsO[A], R, E, F, o, _invoke_O[A, R, E, F, raising]](arguments^, function.function))


def mut_owned[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, o: ImmOrigin, //,
              F: def(mut A, var B) -> R](ref[o] function: F) -> _NativeMutOwnedRef[A, B, R, Never, F, False, o]:
    """Borrow a native callback taking a mutable argument and an owned argument.

    Use `attempt(mut_owned(function), first, second^)`. Mutation of `first`
    remains visible even when the callback raises.

    This borrows the callback without invoking or copying it. Keep the callback
    alive while the adapter is used. Pure callbacks produce a `Never` error
    channel; raising callbacks retain their exact declared error type.
    Select the adapter matching the callback convention: incompatible factory
    calls can crash the Mojo 1.2 compiler instead of producing a diagnostic.

    Parameters:
        A: The mutable first argument type.
        B: The owned second argument type.
        R: The result type.
        o: The borrowed callback origin, inferred.
        F: The exact native function or closure type.

    Args:
        function: The native callback, borrowed with its captures and origin.

    Returns:
        A reusable borrowed adapter for `attempt` with a mutable/owned pair.
    """
    return _NativeMutOwnedRef[A, B, R, Never, F, False, o](Pointer(to=function))


def mut_owned[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
              E: Movable & Deinitable, o: ImmOrigin, //,
              F: def(mut A, var B) raises E -> R](ref[o] function: F) -> _NativeMutOwnedRef[A, B, R, E, F, True, o]:
    """Borrow a raising native callback, retaining its exact error type."""
    return _NativeMutOwnedRef[A, B, R, E, F, True, o](Pointer(to=function))


def attempt[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
            E: Movable & Deinitable, F: Movable & Deinitable, raising: Bool,
            o: ImmOrigin, q: MutOrigin](
    function: _NativeMutOwnedRef[A, B, R, E, F, raising, o], ref[q] first: A, var second: B
) -> Result[R, E]:
    """Call the borrowed convention adapter once and capture its exact outcome."""
    var arguments = _ArgumentsMO[A, B, origin_of(first)](Pointer(to=first), second^)
    return attempt_once(_BoundThunk[_ArgumentsMO[A, B, origin_of(first)], R, E, F, o, _invoke_MO[A, B, origin_of(first), R, E, F, raising]](arguments^, function.function))


def mut_owned_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable,
                     R: Movable & Deinitable, o: ImmOrigin, //,
                     F: def(mut A, var B, /, var **kwargs: K) -> R](ref[o] function: F) -> _NativeMutOwnedKeywordsRef[A, B, K, R, Never, F, False, o]:
    """Borrow a native callback taking a mutable/owned pair and a keyword pack.

    Use `attempt_kwargs(mut_owned_kwargs(function), first, second^, key=value)`.
    The homogeneous native keyword pack may be empty. Mutation of `first`
    remains visible even when the callback raises.

    This borrows the callback without invoking or copying it. Keep the callback
    alive while the adapter is used. Pure callbacks produce a `Never` error
    channel; raising callbacks retain their exact declared error type.
    Select the adapter matching the callback convention: incompatible factory
    calls can crash the Mojo 1.2 compiler instead of producing a diagnostic.

    Parameters:
        A: The mutable first argument type.
        B: The owned second argument type.
        K: The owned keyword value type.
        R: The result type.
        o: The borrowed callback origin, inferred.
        F: The exact native function or closure type.

    Args:
        function: The native callback, borrowed with its captures and origin.

    Returns:
        A reusable borrowed adapter for `attempt_kwargs` with a mutable/owned pair.
    """
    return _NativeMutOwnedKeywordsRef[A, B, K, R, Never, F, False, o](Pointer(to=function))


def mut_owned_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable,
                     R: Movable & Deinitable, E: Movable & Deinitable, o: ImmOrigin, //,
                     F: def(mut A, var B, /, var **kwargs: K) raises E -> R](ref[o] function: F) -> _NativeMutOwnedKeywordsRef[A, B, K, R, E, F, True, o]:
    """Borrow a raising native callback, retaining its exact error type."""
    return _NativeMutOwnedKeywordsRef[A, B, K, R, E, F, True, o](Pointer(to=function))


def attempt_kwargs[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable,
                   R: Movable & Deinitable, E: Movable & Deinitable, F: Movable & Deinitable,
                   raising: Bool, o: ImmOrigin, q: MutOrigin](
    function: _NativeMutOwnedKeywordsRef[A, B, K, R, E, F, raising, o], ref[q] first: A, var second: B, /, var **values: K
) -> Result[R, E]:
    """Call the borrowed mixed adapter once with a native keyword pack."""
    var arguments = _ArgumentsMOK[A, B, origin_of(first), K](Pointer(to=first), second^, values^)
    return attempt_once(_BoundThunk[_ArgumentsMOK[A, B, origin_of(first), K], R, E, F, o, _invoke_MOK[A, B, origin_of(first), K, R, E, F, raising]](arguments^, function.function))
