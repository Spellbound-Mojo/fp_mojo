"""Transform native pair components through existing unary composition."""
from std.builtin.rebind import downcast
from fp.callables.protocols import UnaryContract
from fp.callables._transforms import _Duplicate
from fp.callables.invoke import _OnceUnaryAvailable
from fp.callables.products import MappedPair
from fp.callables.native import NativeUnary
from .composition import Composition, flow


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


comptime Split[F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Composition[False, 1, MappedPair[F, G.Arg, True], MappedPair[G, F.Out, False]]
"""A composition applying one unary callback to each element of an owned pair.

Returned by `split(left, right)`. This is an alias for ordinary composition of
`first` and `second`, so receiver capabilities, copying, errors and origins
follow those existing owners. The left callback runs before the right callback.

Parameters:
    F: The first element's callback type.
    G: The second element's callback type.
"""


def split[F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](
    var left: F, var right: G
) -> Split[F, G] where _OnceUnaryAvailable[F] and _OnceUnaryAvailable[G]:
    """Transform both elements of an owned pair, inferring their types.

    `split(f, g)((a, b))` produces `(f(a), g(b))`. Construction owns both
    callbacks without invoking or copying them. Each call moves the elements,
    invokes the left callback first, then invokes the right callback. If the
    left callback raises, the right callback is skipped. Raising callbacks must
    share one exact error type; non-raising callbacks may join either side.

    Shared, mutable and consuming calls are available when both callbacks
    support that receiver. Capturing unary closures enter through `as_unary`.
    Native no-value outputs remain `type_of(None)` elements in the result.

    Parameters:
        F: The first element's callback type.
        G: The second element's callback type.

    Args:
        left: The first element's callback, moved into the composition.
        right: The second element's callback, moved into the composition.

    Returns:
        A composition from `Tuple[F.Arg, G.Arg]` to `Tuple[F.Out, G.Out]`.
    """
    return flow(first[G.Arg](left^), second[F.Out](right^))


# --- pair split native admission (generated) ---
def split[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    var left: F, ref[q1] right: def(var A1) thin -> R1
) -> Split[F, NativeUnary[A1, R1, Never, type_of(right), False]] where _OnceUnaryAvailable[F]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    var left: F, right: def(var A1) thin -> R1
) -> Split[F, NativeUnary[A1, R1, Never, type_of(right), False]] where _OnceUnaryAvailable[F] and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    var left: F, right: def(var A1) thin -> R1
) -> Split[F, NativeUnary[A1, R1, Never, type_of(right), False]] where _OnceUnaryAvailable[F] and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    var left: F, right: def(var A1) thin -> R1
) -> Split[F, NativeUnary[A1, R1, Never, type_of(right), False]] where _OnceUnaryAvailable[F]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    var left: F, ref[q1] right: def(var A1) thin
) -> Split[F, NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _OnceUnaryAvailable[F]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    var left: F, right: def(var A1) thin
) -> Split[F, NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _OnceUnaryAvailable[F]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    var left: F, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[F, NativeUnary[A1, R1, E1, type_of(right), True]] where _OnceUnaryAvailable[F]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    var left: F, right: def(var A1) raises E1 thin -> R1
) -> Split[F, NativeUnary[A1, R1, E1, type_of(right), True]] where _OnceUnaryAvailable[F] and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    var left: F, right: def(var A1) raises E1 thin -> R1
) -> Split[F, NativeUnary[A1, R1, E1, type_of(right), True]] where _OnceUnaryAvailable[F] and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    var left: F, right: def(var A1) raises E1 thin -> R1
) -> Split[F, NativeUnary[A1, R1, E1, type_of(right), True]] where _OnceUnaryAvailable[F]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    var left: F, ref[q1] right: def(var A1) raises E1 thin
) -> Split[F, NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _OnceUnaryAvailable[F]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    var left: F, right: def(var A1) raises E1 thin
) -> Split[F, NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _OnceUnaryAvailable[F]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(left^, NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, G: UnaryContract & Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, var right: G
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], G] where _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), right^)


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) thin -> R0, var right: G
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], G] where not conforms_to(A0, RegisterPassable) and _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), right^)


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) thin -> R0, var right: G
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], G] where not conforms_to(R0, RegisterPassable) and _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), right^)


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) thin -> R0, var right: G
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], G] where _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), right^)


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, G: UnaryContract & Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, var right: G
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], G] where _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), right^)


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) thin
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) thin, var right: G
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], G] where _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), right^)


def split[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) thin
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, G: UnaryContract & Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, var right: G
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], G] where _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), right^)


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, var right: G
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], G] where not conforms_to(A0, RegisterPassable) and _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), right^)


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, var right: G
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], G] where not conforms_to(R0, RegisterPassable) and _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), right^)


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, var right: G
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], G] where _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), right^)


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, G: UnaryContract & Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, var right: G
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], G] where _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), right^)


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) thin
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, var right: G
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], G] where _OnceUnaryAvailable[G]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        G: The second element's library callback type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), right^)


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) thin
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) thin
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable):
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def split[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin
) -> Split[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Transform both pair elements with native or library unary callbacks.

    Types are inferred from the callbacks. Construction stores native pointers
    and owns library callbacks without invoking them. Pair transfer, left-to-right
    execution, receiver capabilities and exact errors follow ordinary composition.

    Parameters:
        A0: The first element's type.
        E0: The first callback's error type.
        A1: The second element's type.
        E1: The second callback's error type.

    Args:
        left: The first element's callback.
        right: The second element's callback.

    Returns:
        A composition transforming both elements of an owned pair.
    """
    return split(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


# --- end pair split native admission ---


comptime _MergeInput[F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = F.Arg == G.Arg and conforms_to(F.Arg, Copyable)

comptime Merge[F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable] = Composition[False, 1, _Duplicate[downcast[F.Arg, Copyable & Deinitable]], MappedPair[F, G.Arg, True], MappedPair[G, F.Out, False]]
"""A flat composition computing two results from one copyable input.

Returned by `merge(left, right)`. Each call makes one input copy for the left
callback and moves the original to the right callback. Callback storage,
receiver capabilities, errors and origins follow ordinary composition.

Parameters:
    F: The first callback's type.
    G: The second callback's type, with the same input as `F`.
"""


def merge[F: UnaryContract & Movable & Deinitable, G: UnaryContract & Movable & Deinitable](
    var left: F, var right: G
) -> Merge[F, G] where _OnceUnaryAvailable[F] and _OnceUnaryAvailable[G] and _MergeInput[F, G]:
    """Compute two results from one copyable input, inferring its type.

    `merge(f, g)(value)` copies the input once for `f` and moves the original
    into `g`. Both callbacks must accept the same exact type, which must be
    `Copyable`. Construction owns the callbacks without invoking or copying
    them. Each call invokes the left callback first; if it raises, the right
    callback is skipped and its unused input is released.

    The result is an ordinary flat composition. Raising callbacks must share
    one exact error type; non-raising callbacks can join either side. Shared,
    mutable and consuming calls require both callbacks to support that receiver.
    Capturing unary closures enter through `as_unary`. Native no-value output
    remains `type_of(None)` in the result pair.

    Parameters:
        F: The first callback's type.
        G: The second callback's type, with the same input as `F`.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition from `F.Arg` to `Tuple[F.Out, G.Out]`.
    """
    return split(left^, right^).compose(_Duplicate[downcast[F.Arg, Copyable & Deinitable]]())


# --- pair merge native admission (generated) ---
def merge[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    var left: F, ref[q1] right: def(var A1) thin -> R1
) -> Merge[F, NativeUnary[A1, R1, Never, type_of(right), False]] where _OnceUnaryAvailable[F] and _MergeInput[F, NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    var left: F, right: def(var A1) thin -> R1
) -> Merge[F, NativeUnary[A1, R1, Never, type_of(right), False]] where _OnceUnaryAvailable[F] and not conforms_to(A1, RegisterPassable) and _MergeInput[F, NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    var left: F, right: def(var A1) thin -> R1
) -> Merge[F, NativeUnary[A1, R1, Never, type_of(right), False]] where _OnceUnaryAvailable[F] and not conforms_to(R1, RegisterPassable) and _MergeInput[F, NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    var left: F, right: def(var A1) thin -> R1
) -> Merge[F, NativeUnary[A1, R1, Never, type_of(right), False]] where _OnceUnaryAvailable[F] and _MergeInput[F, NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    var left: F, ref[q1] right: def(var A1) thin
) -> Merge[F, NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _OnceUnaryAvailable[F] and _MergeInput[F, NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    var left: F, right: def(var A1) thin
) -> Merge[F, NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _OnceUnaryAvailable[F] and _MergeInput[F, NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    var left: F, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[F, NativeUnary[A1, R1, E1, type_of(right), True]] where _OnceUnaryAvailable[F] and _MergeInput[F, NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    var left: F, right: def(var A1) raises E1 thin -> R1
) -> Merge[F, NativeUnary[A1, R1, E1, type_of(right), True]] where _OnceUnaryAvailable[F] and not conforms_to(A1, RegisterPassable) and _MergeInput[F, NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    var left: F, right: def(var A1) raises E1 thin -> R1
) -> Merge[F, NativeUnary[A1, R1, E1, type_of(right), True]] where _OnceUnaryAvailable[F] and not conforms_to(R1, RegisterPassable) and _MergeInput[F, NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    var left: F, right: def(var A1) raises E1 thin -> R1
) -> Merge[F, NativeUnary[A1, R1, E1, type_of(right), True]] where _OnceUnaryAvailable[F] and _MergeInput[F, NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    var left: F, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[F, NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _OnceUnaryAvailable[F] and _MergeInput[F, NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[F: UnaryContract & Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    var left: F, right: def(var A1) raises E1 thin
) -> Merge[F, NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _OnceUnaryAvailable[F] and _MergeInput[F, NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        F: The first element's library callback type.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(left^, NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, G: UnaryContract & Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, var right: G
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], G] where _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), right^)


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) thin -> R0, var right: G
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], G] where not conforms_to(A0, RegisterPassable) and _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), right^)


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) thin -> R0, var right: G
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], G] where not conforms_to(R0, RegisterPassable) and _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), right^)


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) thin -> R0, var right: G
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], G] where _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), right^)


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin -> R0, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, G: UnaryContract & Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, var right: G
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], G] where _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), right^)


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) thin
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) thin, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) thin, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) thin, var right: G
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], G] where _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), right^)


def merge[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) thin
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) thin, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) thin, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), Never, type_of(left), False], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), Never, type_of(left), False](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, G: UnaryContract & Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, var right: G
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], G] where _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), right^)


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, var right: G
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], G] where not conforms_to(A0, RegisterPassable) and _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), right^)


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(A0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, var right: G
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], G] where not conforms_to(R0, RegisterPassable) and _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), right^)


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: Movable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where not conforms_to(R0, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, var right: G
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], G] where _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), right^)


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin -> R0, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, R0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin -> R0, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, R0, E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        R0: The first callback's result type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, R0, E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, G: UnaryContract & Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, var right: G
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], G] where _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), right^)


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) thin
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    ref[q0] left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: Movable & Deinitable, E0: Movable & Deinitable, q0: ImmOrigin, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    ref[q0] left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        q0: The first pointer admission borrow's origin.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, G: UnaryContract & Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, var right: G
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], G] where _OnceUnaryAvailable[G] and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], G]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        G: The second element's library callback type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), right^)


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) thin
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) thin
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), Never, type_of(right), False]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), Never, type_of(right), False](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(A1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: Movable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where not conforms_to(R1, RegisterPassable) and _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, R1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin -> R1
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, R1, E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        R1: The second callback's result type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, R1, E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: Movable & Deinitable, E1: Movable & Deinitable, q1: ImmOrigin, //](
    left: def(var A0) raises E0 thin, ref[q1] right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        E1: The second callback's error type.
        q1: The second pointer admission borrow's origin.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


def merge[A0: RegisterPassable & Deinitable, E0: Movable & Deinitable, A1: RegisterPassable & Deinitable, E1: Movable & Deinitable, //](
    left: def(var A0) raises E0 thin, right: def(var A1) raises E1 thin
) -> Merge[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]] where _MergeInput[NativeUnary[A0, type_of(None), E0, type_of(left), True], NativeUnary[A1, type_of(None), E1, type_of(right), True]]:
    """Compute two results from one copyable input with unary callbacks.

    Both callbacks must accept the same copyable type. Each call gives one input
    copy to the left callback and the original to the right. Construction stores
    callbacks without invoking them. Execution and exact errors follow composition.

    Parameters:
        A0: The first callback's input type.
        E0: The first callback's error type.
        A1: The second callback's input type.
        E1: The second callback's error type.

    Args:
        left: The callback receiving one copy of each input.
        right: The callback receiving each original input.

    Returns:
        A composition computing both results from one copyable input.
    """
    return merge(NativeUnary[A0, type_of(None), E0, type_of(left), True](left), NativeUnary[A1, type_of(None), E1, type_of(right), True](right))


# --- end pair merge native admission ---
