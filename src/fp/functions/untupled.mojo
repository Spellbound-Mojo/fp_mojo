"""Adapt a unary pair consumer to two owned arguments through composition."""
from std.builtin.variadics import TypeList
from fp.callables.protocols import UnaryContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables._transforms import _Pair
from fp.callables.native import NativeUnary
from .composition import Composition, flow, _AllOnce


comptime Untupled[A: Movable & Deinitable, B: Movable & Deinitable, F: UnaryContract & Movable & Deinitable] = Composition[False, 2, _Pair[A, B], F]
"""A binary composition passing its two owned arguments to a pair consumer.

Returned by `untupled(function)`. This alias adds no storage or invocation
policy: pair construction and callback execution use ordinary composition.

Parameters:
    A: The first owned argument's type.
    B: The second owned argument's type.
    F: The unary pair consumer's type.
"""


def untupled[A: Movable & Deinitable, B: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](
    var function: F
) -> Untupled[A, B, F] where F.Arg == Tuple[A, B] and _OnceUnaryAvailable[F]:
    """Call a unary pair consumer with two arguments, inferring both types.

    `untupled(f)(a, b)` calls `f((a, b))`. Construction owns the callback without
    invoking it. Each call moves both arguments into a pair without copying.
    Shared, mutable and consuming receiver modes, exact native errors and result
    origins follow the wrapped callback. Capturing closures use `as_unary` first.

    Parameters:
        A: The first argument's type, inferred from the callback's pair input.
        B: The second argument's type, inferred from the callback's pair input.
        F: The unary library callback's type.

    Args:
        function: The pair consumer, moved into the composition.

    Returns:
        A binary composition preserving the callback's result and error types.
    """
    # Expose the existing planner's capability proof for this generic stage list.
    comptime assert _AllOnce[TypeList.of[Trait=Movable & Deinitable, _Pair[A, B], F]()]
    return flow(_Pair[A, B](), function^)


# --- untupled native admission (generated) ---
def untupled[T: Movable & Deinitable, R: Movable & Deinitable, q: ImmOrigin, //, A: Movable & Deinitable, B: Movable & Deinitable](
    ref[q] function: def(var T) thin -> R
) -> Untupled[A, B, NativeUnary[T, R, Never, type_of(function), False]] where T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        R: The native result type.
        q: The temporary pointer admission borrow's origin.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, R, Never, type_of(function), False](function))


def untupled[T: Movable & Deinitable, R: RegisterPassable & Deinitable, //, A: Movable & Deinitable, B: Movable & Deinitable](
    function: def(var T) thin -> R
) -> Untupled[A, B, NativeUnary[T, R, Never, type_of(function), False]] where not conforms_to(T, RegisterPassable) and T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        R: The native result type.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, R, Never, type_of(function), False](function))


def untupled[T: RegisterPassable & Deinitable, R: Movable & Deinitable, //, A: Movable & Deinitable, B: Movable & Deinitable](
    function: def(var T) thin -> R
) -> Untupled[A, B, NativeUnary[T, R, Never, type_of(function), False]] where not conforms_to(R, RegisterPassable) and T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        R: The native result type.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, R, Never, type_of(function), False](function))


def untupled[T: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, //, A: Movable & Deinitable, B: Movable & Deinitable](
    function: def(var T) thin -> R
) -> Untupled[A, B, NativeUnary[T, R, Never, type_of(function), False]] where T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        R: The native result type.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, R, Never, type_of(function), False](function))


def untupled[T: Movable & Deinitable, //, A: Movable & Deinitable, B: Movable & Deinitable](
    function: def(var T) thin
) -> Untupled[A, B, NativeUnary[T, type_of(None), Never, type_of(function), False]] where T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, type_of(None), Never, type_of(function), False](function))


def untupled[T: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, q: ImmOrigin, //, A: Movable & Deinitable, B: Movable & Deinitable](
    ref[q] function: def(var T) raises E thin -> R
) -> Untupled[A, B, NativeUnary[T, R, E, type_of(function), True]] where T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        R: The native result type.
        E: The native error type.
        q: The temporary pointer admission borrow's origin.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, R, E, type_of(function), True](function))


def untupled[T: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //, A: Movable & Deinitable, B: Movable & Deinitable](
    function: def(var T) raises E thin -> R
) -> Untupled[A, B, NativeUnary[T, R, E, type_of(function), True]] where not conforms_to(T, RegisterPassable) and T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        R: The native result type.
        E: The native error type.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, R, E, type_of(function), True](function))


def untupled[T: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, A: Movable & Deinitable, B: Movable & Deinitable](
    function: def(var T) raises E thin -> R
) -> Untupled[A, B, NativeUnary[T, R, E, type_of(function), True]] where not conforms_to(R, RegisterPassable) and T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        R: The native result type.
        E: The native error type.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, R, E, type_of(function), True](function))


def untupled[T: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //, A: Movable & Deinitable, B: Movable & Deinitable](
    function: def(var T) raises E thin -> R
) -> Untupled[A, B, NativeUnary[T, R, E, type_of(function), True]] where T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        R: The native result type.
        E: The native error type.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, R, E, type_of(function), True](function))


def untupled[T: Movable & Deinitable, E: Movable & Deinitable, //, A: Movable & Deinitable, B: Movable & Deinitable](
    function: def(var T) raises E thin
) -> Untupled[A, B, NativeUnary[T, type_of(None), E, type_of(function), True]] where T == Tuple[A, B]:
    """Adapt a plain unary pair consumer or stored thin pointer to two arguments.

    Both argument types are inferred from the native pair input. Construction
    stores the pointer; pair transfer and execution use ordinary composition.

    Parameters:
        T: The native pair input type.
        E: The native error type.
        A: The first argument's type, inferred from the pair input.
        B: The second argument's type, inferred from the pair input.

    Args:
        function: The unary native pair consumer or stored pointer.

    Returns:
        A binary composition preserving the native result and error types.
    """
    return untupled[A, B](NativeUnary[T, type_of(None), E, type_of(function), True](function))


# --- end untupled native admission ---
