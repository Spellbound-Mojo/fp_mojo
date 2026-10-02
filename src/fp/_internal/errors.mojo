"""Exact native error identity and propagation shared by higher-order APIs."""
from std.builtin.rebind import rebind_var, downcast
from std.os import abort


comptime _NativeError[E: AnyType]: Movable & Deinitable = Never if E == Never else downcast[E, Movable & Deinitable]
"""An error type inferred under an `AnyType` bound, as a value-bounded parameter.

Inferring a pure function's error under a `Movable & Deinitable` bound yields an
uninhabited type that is not equal to `Never`, and the pinned compiler crashes on
a `try` around a call that raises it. A signature that catches a callback's
error infers it as `AnyType` and passes it on through this alias.
"""


comptime _CommonError[A: Movable & Deinitable, B: Movable & Deinitable] = B if A == Never else A


comptime _ErrorCompatible[E: AnyType, Actual: AnyType]: Bool = Actual == Never or Actual == E


def _compatible[E: Movable & Deinitable, Actual: Movable & Deinitable]() -> Bool:
    comptime assert _ErrorCompatible[E, Actual], "callback errors: incompatible native error type; got " + reflect[Actual].name() + "; expected " + reflect[E].name() + "; use an explicit common error mapping"
    return True


def _propagate_error[E: Movable & Deinitable, Actual: Movable & Deinitable](
    var error: Actual
) raises E -> Never where _ErrorCompatible[E, Actual]:
    """Move an admitted error unchanged; Never has no reachable error value."""
    comptime if Actual == Never:
        abort("native errors: unreachable Never error")
    else:
        raise rebind_var[E](error^)


# Call a plain function and raise its error as `E`. The function's error is
# inferred as `AnyType` and normalized (see `_NativeError`) before the `try`.

def _forward[E: Movable & Deinitable, A: AnyType, O: Movable & Deinitable, X: AnyType](
    function: def(A) raises X thin -> O, a: A
) raises E -> O:
    comptime assert _ErrorCompatible[E, _NativeError[X]]
    var f = rebind[def(A) raises _NativeError[X] thin -> O](function)
    try:
        return f(a)
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)


def _forward[E: Movable & Deinitable, A: AnyType, B: AnyType, O: Movable & Deinitable, X: AnyType](
    function: def(A, B) raises X thin -> O, a: A, b: B
) raises E -> O:
    comptime assert _ErrorCompatible[E, _NativeError[X]]
    var f = rebind[def(A, B) raises _NativeError[X] thin -> O](function)
    try:
        return f(a, b)
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)


def _forward[E: Movable & Deinitable, A: AnyType, B: AnyType, C: AnyType, O: Movable & Deinitable, X: AnyType](
    function: def(A, B, C) raises X thin -> O, a: A, b: B, c: C
) raises E -> O:
    comptime assert _ErrorCompatible[E, _NativeError[X]]
    var f = rebind[def(A, B, C) raises _NativeError[X] thin -> O](function)
    try:
        return f(a, b, c)
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)
