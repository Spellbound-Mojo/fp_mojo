"""Transform one native pair component through a reusable unary callback."""
from fp.callables.protocols import UnaryContract
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables.products import MappedPair
from fp.callables.native import NativeUnary


def first[Other: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F) -> MappedPair[F, Other, True] where _OnceUnaryAvailable[F]:
    """Transform the first element of a native pair, moving the second unchanged.

    The result owns the callback without invoking it. Native no-value output
    remains `type_of(None)` in the pair, distinct from explicit `NoneType`.
    Shared, mutable and consuming callback modes retain their meaning.

    Parameters:
        Other: The untouched second element's type.
        F: The unary library callback's type.

    Args:
        function: The callback, moved into the wrapper.

    Returns:
        A callable from `Tuple[F.Arg, Other]` to `Tuple[F.Out, Other]`.
    """
    return MappedPair[F, Other, True](function^)


def second[Other: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var function: F) -> MappedPair[F, Other, False] where _OnceUnaryAvailable[F]:
    """Transform the second element of a native pair, moving the first unchanged.

    The result owns the callback without invoking it. Native no-value output
    remains `type_of(None)` in the pair, distinct from explicit `NoneType`.
    Shared, mutable and consuming callback modes retain their meaning.

    Parameters:
        Other: The untouched first element's type.
        F: The unary library callback's type.

    Args:
        function: The callback, moved into the wrapper.

    Returns:
        A callable from `Tuple[Other, F.Arg]` to `Tuple[Other, F.Out]`.
    """
    return MappedPair[F, Other, False](function^)


# --- pair projection native admission (generated) ---
def first[A: Movable & Deinitable, R: Movable & Deinitable, q: ImmOrigin, //, Other: Movable & Deinitable](
    ref[q] function: def(var A) thin -> R
) -> MappedPair[NativeUnary[A, R, Never, type_of(function), False], Other, True]:
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        q: The temporary pointer admission borrow's origin.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, R, Never, type_of(function), False](function))


def first[A: Movable & Deinitable, R: RegisterPassable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) thin -> R
) -> MappedPair[NativeUnary[A, R, Never, type_of(function), False], Other, True] where not conforms_to(A, RegisterPassable):
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, R, Never, type_of(function), False](function))


def first[A: RegisterPassable & Deinitable, R: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) thin -> R
) -> MappedPair[NativeUnary[A, R, Never, type_of(function), False], Other, True] where not conforms_to(R, RegisterPassable):
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, R, Never, type_of(function), False](function))


def first[A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) thin -> R
) -> MappedPair[NativeUnary[A, R, Never, type_of(function), False], Other, True]:
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, R, Never, type_of(function), False](function))


def first[A: Movable & Deinitable, q: ImmOrigin, //, Other: Movable & Deinitable](
    ref[q] function: def(var A) thin
) -> MappedPair[NativeUnary[A, type_of(None), Never, type_of(function), False], Other, True]:
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        q: The temporary pointer admission borrow's origin.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, type_of(None), Never, type_of(function), False](function))


def first[A: RegisterPassable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) thin
) -> MappedPair[NativeUnary[A, type_of(None), Never, type_of(function), False], Other, True]:
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, type_of(None), Never, type_of(function), False](function))


def first[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, q: ImmOrigin, //, Other: Movable & Deinitable](
    ref[q] function: def(var A) raises E thin -> R
) -> MappedPair[NativeUnary[A, R, E, type_of(function), True], Other, True]:
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        E: The callback error type.
        q: The temporary pointer admission borrow's origin.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, R, E, type_of(function), True](function))


def first[A: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) raises E thin -> R
) -> MappedPair[NativeUnary[A, R, E, type_of(function), True], Other, True] where not conforms_to(A, RegisterPassable):
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        E: The callback error type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, R, E, type_of(function), True](function))


def first[A: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) raises E thin -> R
) -> MappedPair[NativeUnary[A, R, E, type_of(function), True], Other, True] where not conforms_to(R, RegisterPassable):
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        E: The callback error type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, R, E, type_of(function), True](function))


def first[A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) raises E thin -> R
) -> MappedPair[NativeUnary[A, R, E, type_of(function), True], Other, True]:
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        E: The callback error type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, R, E, type_of(function), True](function))


def first[A: Movable & Deinitable, E: Movable & Deinitable, q: ImmOrigin, //, Other: Movable & Deinitable](
    ref[q] function: def(var A) raises E thin
) -> MappedPair[NativeUnary[A, type_of(None), E, type_of(function), True], Other, True]:
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        E: The callback error type.
        q: The temporary pointer admission borrow's origin.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, type_of(None), E, type_of(function), True](function))


def first[A: RegisterPassable & Deinitable, E: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) raises E thin
) -> MappedPair[NativeUnary[A, type_of(None), E, type_of(function), True], Other, True]:
    """Transform the first pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        E: The callback error type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the first element of its owned pair.
    """
    return first[Other](NativeUnary[A, type_of(None), E, type_of(function), True](function))


def second[A: Movable & Deinitable, R: Movable & Deinitable, q: ImmOrigin, //, Other: Movable & Deinitable](
    ref[q] function: def(var A) thin -> R
) -> MappedPair[NativeUnary[A, R, Never, type_of(function), False], Other, False]:
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        q: The temporary pointer admission borrow's origin.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, R, Never, type_of(function), False](function))


def second[A: Movable & Deinitable, R: RegisterPassable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) thin -> R
) -> MappedPair[NativeUnary[A, R, Never, type_of(function), False], Other, False] where not conforms_to(A, RegisterPassable):
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, R, Never, type_of(function), False](function))


def second[A: RegisterPassable & Deinitable, R: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) thin -> R
) -> MappedPair[NativeUnary[A, R, Never, type_of(function), False], Other, False] where not conforms_to(R, RegisterPassable):
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, R, Never, type_of(function), False](function))


def second[A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) thin -> R
) -> MappedPair[NativeUnary[A, R, Never, type_of(function), False], Other, False]:
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, R, Never, type_of(function), False](function))


def second[A: Movable & Deinitable, q: ImmOrigin, //, Other: Movable & Deinitable](
    ref[q] function: def(var A) thin
) -> MappedPair[NativeUnary[A, type_of(None), Never, type_of(function), False], Other, False]:
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        q: The temporary pointer admission borrow's origin.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, type_of(None), Never, type_of(function), False](function))


def second[A: RegisterPassable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) thin
) -> MappedPair[NativeUnary[A, type_of(None), Never, type_of(function), False], Other, False]:
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, type_of(None), Never, type_of(function), False](function))


def second[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, q: ImmOrigin, //, Other: Movable & Deinitable](
    ref[q] function: def(var A) raises E thin -> R
) -> MappedPair[NativeUnary[A, R, E, type_of(function), True], Other, False]:
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        E: The callback error type.
        q: The temporary pointer admission borrow's origin.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, R, E, type_of(function), True](function))


def second[A: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) raises E thin -> R
) -> MappedPair[NativeUnary[A, R, E, type_of(function), True], Other, False] where not conforms_to(A, RegisterPassable):
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        E: The callback error type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, R, E, type_of(function), True](function))


def second[A: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) raises E thin -> R
) -> MappedPair[NativeUnary[A, R, E, type_of(function), True], Other, False] where not conforms_to(R, RegisterPassable):
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        E: The callback error type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, R, E, type_of(function), True](function))


def second[A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) raises E thin -> R
) -> MappedPair[NativeUnary[A, R, E, type_of(function), True], Other, False]:
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        R: The callback result type.
        E: The callback error type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, R, E, type_of(function), True](function))


def second[A: Movable & Deinitable, E: Movable & Deinitable, q: ImmOrigin, //, Other: Movable & Deinitable](
    ref[q] function: def(var A) raises E thin
) -> MappedPair[NativeUnary[A, type_of(None), E, type_of(function), True], Other, False]:
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        E: The callback error type.
        q: The temporary pointer admission borrow's origin.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, type_of(None), E, type_of(function), True](function))


def second[A: RegisterPassable & Deinitable, E: Movable & Deinitable, //, Other: Movable & Deinitable](
    function: def(var A) raises E thin
) -> MappedPair[NativeUnary[A, type_of(None), E, type_of(function), True], Other, False]:
    """Transform the second pair element with a plain function or stored thin pointer.

    The untouched element is moved unchanged. Construction stores the pointer;
    pair transfer and invocation use the same library callback implementation.

    Parameters:
        A: The transformed element's type.
        E: The callback error type.
        Other: The untouched pair element's type.

    Args:
        function: The unary native function or stored pointer.

    Returns:
        A callable transforming only the second element of its owned pair.
    """
    return second[Other](NativeUnary[A, type_of(None), E, type_of(function), True](function))


# --- end pair projection native admission ---
