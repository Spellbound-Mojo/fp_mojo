"""Calls through the callable protocols: borrowed endpoints and receiver dispatch."""

from std.builtin.rebind import rebind_var, rebind, downcast
from fp._internal.errors import _ErrorCompatible, _compatible, _propagate_error
from .protocols import BorrowCallable, BorrowOnceCallable, BorrowCallContract


comptime BorrowCallCompatible[E: Movable & Deinitable, H: BorrowCallContract, T: AnyType = H.Payload]: Bool = (
    T == H.Payload and (_ErrorCompatible[E, H.Failure])
)
"""Whether `invoke_borrowed[E]` accepts handler `H` with a payload of type `T`.

True when `T` is exactly `H.Payload`, including embedded origins, and `H`
raises `E` or nothing. A generic function that forwards a borrowed callback
carries it in its `where` clause.

Parameters:
    E: The error type of the caller.
    H: The borrowed callable.
    T: The payload type; `H.Payload` by default.
"""


def invoke_borrowed[E: Movable & Deinitable, H: BorrowCallable, T: AnyType](
    ref payload: T, handler: H
) raises E -> H.Result where BorrowCallCompatible[E, H, T]:
    """Call a `BorrowCallable` with a borrowed payload, raising its error as `E`.

    The error is moved unchanged; it is never converted, erased or recovered.

    Parameters:
        E: The error type the call raises: the handler's own error, or any
            type when the handler raises nothing.
        H: The handler's type.
        T: The payload's type, which must be exactly `H.Payload`.

    Args:
        payload: The argument, borrowed for the call.
        handler: The handler, borrowed.

    Returns:
        The handler's result.

    Raises:
        The handler's error, as `E`.
    """
    comptime assert _compatible[E, H.Failure]()
    try:
        return handler.invoke(rebind[H.Payload](payload))
    except error:
        comptime assert _ErrorCompatible[E, type_of(error)]
        _propagate_error[E](error^)


def invoke_borrowed_once[E: Movable & Deinitable, H: BorrowOnceCallable, T: AnyType](
    ref payload: T, var handler: H
) raises E -> H.Result where BorrowCallCompatible[E, H, T]:
    """Call a `BorrowOnceCallable` once with a borrowed payload, consuming it.

    Parameters:
        E: The error type the call raises: the handler's own error, or any
            type when the handler raises nothing.
        H: The handler's type.
        T: The payload's type, which must be exactly `H.Payload`.

    Args:
        payload: The argument, borrowed for the call.
        handler: The handler, consumed by the call.

    Returns:
        The handler's result.

    Raises:
        The handler's error, as `E`.
    """
    # Native consuming and shared endpoint signatures require separate adapters;
    # compatibility and error propagation remain shared with invoke_borrowed.
    try:
        return handler^.invoke_once(rebind[H.Payload](payload))
    except error:
        _propagate_error[E](error^)


from .protocols import (UnaryContract, Unary, MutableUnary, OnceUnary,
                                    BinaryContract, Binary, MutableBinary, OnceBinary,
                                    ThunkContract, Thunk, MutableThunk, OnceThunk)


# Fixed-arity receiver dispatch: one call prefers the consuming mode, repeated
# calls prefer exclusive access, then a shared receiver. Each arity has its own
# native call signature.
comptime RepeatableUnary[F: UnaryContract] = conforms_to(F, Unary) or conforms_to(F, MutableUnary)
"""Whether a unary callback stays usable after a call: it has a shared or exclusive receiver.

`call_repeated` requires it. Generic code that calls a callback more than once
asserts it first, so a consuming-only callback is rejected when the program
compiles.

Parameters:
    F: The callback's type.
"""
comptime RepeatableBinary[F: BinaryContract] = conforms_to(F, Binary) or conforms_to(F, MutableBinary)
"""Whether a binary callback stays usable after a call; `call_repeated` requires it.

Parameters:
    F: The callback's type.
"""
comptime RepeatableThunk[F: ThunkContract] = conforms_to(F, Thunk) or conforms_to(F, MutableThunk)
"""Whether a thunk stays usable after a call; `call_repeated` requires it.

Parameters:
    F: The thunk's type.
"""


def call_once[F: UnaryContract & Movable & Deinitable](var f: F, var arg: F.Arg) raises F.Error -> F.Out:
    """Call a unary callback once, in whichever receiver mode it has.

    A consuming callback is consumed; otherwise the exclusive, then the shared
    receiver is used. Algorithms call a callback they run once through this.

    Parameters:
        F: The callback's type: any `UnaryContract` with at least one receiver mode.

    Args:
        f: The callback, consumed.
        arg: The argument, consumed.

    Returns:
        The callback's result.

    Raises:
        The callback's error, unchanged.
    """
    comptime if conforms_to(F, OnceUnary):
        comptime D = downcast[F, OnceUnary]
        try:
            return rebind_var[F.Out](rebind_var[D](f^).call_once(rebind_var[D.Arg](arg^)))
        except error:
            comptime assert _ErrorCompatible[F.Error, type_of(error)]
            _propagate_error[F.Error](error^)
    else:
        comptime assert RepeatableUnary[F], "unary callback implements no receiver mode"
        return call_repeated(f, arg^)


def call_repeated[F: UnaryContract & Movable & Deinitable](mut f: F, var arg: F.Arg
) raises F.Error -> F.Out where RepeatableUnary[F]:
    """Call a unary callback that stays usable afterwards.

    The exclusive receiver is used when the callback has one, otherwise the
    shared one. Algorithms that call a callback for every element call it
    through this.

    Parameters:
        F: The callback's type; `RepeatableUnary[F]` must hold.

    Args:
        f: The callback, borrowed mutably.
        arg: The argument, consumed.

    Returns:
        The callback's result.

    Raises:
        The callback's error, unchanged.
    """
    try:
        comptime if conforms_to(F, MutableUnary):
            comptime D = downcast[F, MutableUnary]
            return rebind_var[F.Out](rebind[D](f).call_mut(rebind_var[D.Arg](arg^)))
        else:
            comptime D = downcast[F, Unary]
            return rebind_var[F.Out](rebind[D](f).call(rebind_var[D.Arg](arg^)))
    except error:
        comptime assert _ErrorCompatible[F.Error, type_of(error)]
        _propagate_error[F.Error](error^)


def call_once[F: BinaryContract & Movable & Deinitable](var f: F, var first: F.First, var second: F.Second
) raises F.Error -> F.Out:
    """Call a binary callback once, in whichever receiver mode it has."""
    comptime if conforms_to(F, OnceBinary):
        comptime D = downcast[F, OnceBinary]
        try:
            return rebind_var[F.Out](rebind_var[D](f^).call_once(rebind_var[D.First](first^), rebind_var[D.Second](second^)))
        except error:
            comptime assert _ErrorCompatible[F.Error, type_of(error)]
            _propagate_error[F.Error](error^)
    else:
        comptime assert RepeatableBinary[F], "binary callback implements no receiver mode"
        return call_repeated(f, first^, second^)


def call_repeated[F: BinaryContract & Movable & Deinitable](mut f: F, var first: F.First, var second: F.Second
) raises F.Error -> F.Out where RepeatableBinary[F]:
    """Call a binary callback that stays usable afterwards."""
    try:
        comptime if conforms_to(F, MutableBinary):
            comptime D = downcast[F, MutableBinary]
            return rebind_var[F.Out](rebind[D](f).call_mut(rebind_var[D.First](first^), rebind_var[D.Second](second^)))
        else:
            comptime D = downcast[F, Binary]
            return rebind_var[F.Out](rebind[D](f).call(rebind_var[D.First](first^), rebind_var[D.Second](second^)))
    except error:
        comptime assert _ErrorCompatible[F.Error, type_of(error)]
        _propagate_error[F.Error](error^)


def call_once[F: ThunkContract & Movable & Deinitable](var f: F) raises F.Error -> F.Out:
    """Call a thunk once, in whichever receiver mode it has."""
    comptime if conforms_to(F, OnceThunk):
        comptime D = downcast[F, OnceThunk]
        try:
            return rebind_var[F.Out](rebind_var[D](f^).call_once())
        except error:
            comptime assert _ErrorCompatible[F.Error, type_of(error)]
            _propagate_error[F.Error](error^)
    else:
        comptime assert RepeatableThunk[F], "thunk implements no receiver mode"
        return call_repeated(f)


def call_repeated[F: ThunkContract & Movable & Deinitable](mut f: F) raises F.Error -> F.Out where RepeatableThunk[F]:
    """Call a thunk that stays usable afterwards."""
    try:
        comptime if conforms_to(F, MutableThunk):
            comptime D = downcast[F, MutableThunk]
            return rebind_var[F.Out](rebind[D](f).call_mut())
        else:
            comptime D = downcast[F, Thunk]
            return rebind_var[F.Out](rebind[D](f).call())
    except error:
        comptime assert _ErrorCompatible[F.Error, type_of(error)]
        _propagate_error[F.Error](error^)
