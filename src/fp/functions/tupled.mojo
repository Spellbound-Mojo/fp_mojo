"""Adapt a binary callable to consume a native pair as its single argument."""
from std.builtin.rebind import downcast, rebind, rebind_var
from fp.callables.protocols import BinaryContract, Binary, UnaryContract, Unary, MutableUnary, OnceUnary
from fp.callables.invoke import RepeatableBinary, _OnceBinaryAvailable
from fp.callables.products import _call_pair_as
from fp.callables._receiver import _SharedBinaryRef, _MutableBinaryRef, _SharedUnaryRef
from fp.callables._views import _UnaryViewable
from fp.callables.native import NativeBinary


@fieldwise_init
struct Tupled[F: BinaryContract & Movable & Deinitable](
    Movable, UnaryContract, Unary where conforms_to(F, Binary),
    _UnaryViewable where conforms_to(F, Binary),
    MutableUnary where RepeatableBinary[F], OnceUnary where _OnceBinaryAvailable[F],
    Copyable where conforms_to(F, Copyable),
):
    """A binary callback consuming one pair, returned by `tupled`.

    `tupled(function)((first, second))` calls the binary function with the two
    owned elements. Nothing runs during construction. Captures, input elements
    and raised errors are transferred without copying; result origins remain
    those of the underlying callback.

    Shared, mutable and consuming calls retain the wrapped receiver's modes.
    Named shared wrappers can be reused by borrow in supported unary callback
    operations. An explicit move transfers the wrapper and its stored callback.

    Parameters:
        F: The wrapped binary callable's type.
    """
    comptime Arg = Tuple[Self.F.First, Self.F.Second]
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    var _function: Self.F

    comptime _View[o: ImmOrigin] = _SharedUnaryRef[downcast[Self, Unary], o]

    def _unary_view[o: ImmOrigin](ref[o] self) -> Self._View[o]:
        comptime assert conforms_to(Self.F, Binary)
        return Self._View[o](Pointer(to=self))

    def call(self, var pair: Self.Arg) raises Self.Error -> Self.Out:
        """Call the wrapped binary callback through a shared receiver.

        Args:
            pair: The two arguments, consumed without copying either element.

        Returns:
            The callback's result, unchanged.

        Raises:
            The callback's exact error type.
        """
        comptime assert conforms_to(Self.F, Binary), "tupled: a shared call requires a Binary"
        comptime B = downcast[Self.F, Binary]
        ref function = rebind[B](self._function)
        comptime assert Self.Arg == Tuple[B.First, B.Second]
        return rebind_var[Self.Out](_call_pair_as[Self.Error](
            _SharedBinaryRef[B, origin_of(function)](Pointer(to=function)),
            rebind_var[Tuple[B.First, B.Second]](pair^)))

    def call_mut(mut self, var pair: Self.Arg) raises Self.Error -> Self.Out:
        """Call with exclusive access, retaining callback state between calls.

        Args:
            pair: The two arguments, consumed.

        Returns:
            The callback's result, unchanged.

        Raises:
            The callback's exact error type.
        """
        comptime assert RepeatableBinary[Self.F], "tupled: a repeated call requires a shared or mutable Binary"
        return _call_pair_as[Self.Error](
            _MutableBinaryRef[Self.F, origin_of(self._function)](Pointer(to=self._function)), pair^)

    def call_once(deinit self, var pair: Self.Arg) raises Self.Error -> Self.Out:
        """Call once, consuming both the wrapper and its pair argument.

        Args:
            pair: The two arguments, consumed.

        Returns:
            The callback's result, unchanged.

        Raises:
            The callback's exact error type.
        """
        comptime assert _OnceBinaryAvailable[Self.F], "tupled: the binary callback must implement a receiver mode"
        return _call_pair_as[Self.Error](self._function^, pair^)

    def __call__(self, var pair: Self.Arg) raises Self.Error -> Self.Out:
        """Call through a shared receiver, as `call` does.

        Args:
            pair: The two arguments, consumed.

        Returns:
            The callback's result, unchanged.

        Raises:
            The callback's exact error type.
        """
        return self.call(pair^)


def tupled[F: BinaryContract & Movable & Deinitable](var function: F) -> Tupled[F] where _OnceBinaryAvailable[F]:
    """Adapt a binary callable to consume a single native pair.

    Construction moves the callable without invoking it. The result keeps its
    receiver capabilities, argument, output and error types. Use it to compose
    a binary callback after a tuple-producing stage or to map a sequence of pairs.

    Parameters:
        F: The binary library callable's type.

    Args:
        function: The callback, moved into the wrapper.

    Returns:
        A `Tupled` callable taking `Tuple[F.First, F.Second]`.
    """
    return Tupled[F](function^)


# --- tupled native admission (generated) ---
def tupled[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, q: ImmOrigin, //](
    ref[q] function: def(var A, var B) thin -> R
) -> Tupled[NativeBinary[A, B, R, Never, type_of(function), False]]:
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.
        q: The temporary pointer admission borrow's origin.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, Never, type_of(function), False](function))


def tupled[A: Movable & Deinitable, B: Movable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> Tupled[NativeBinary[A, B, R, Never, type_of(function), False]] where not conforms_to(A, RegisterPassable) and not conforms_to(B, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, Never, type_of(function), False](function))


def tupled[A: Movable & Deinitable, B: RegisterPassable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> Tupled[NativeBinary[A, B, R, Never, type_of(function), False]] where not conforms_to(A, RegisterPassable) and not conforms_to(R, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, Never, type_of(function), False](function))


def tupled[A: Movable & Deinitable, B: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> Tupled[NativeBinary[A, B, R, Never, type_of(function), False]] where not conforms_to(A, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, Never, type_of(function), False](function))


def tupled[A: RegisterPassable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> Tupled[NativeBinary[A, B, R, Never, type_of(function), False]] where not conforms_to(B, RegisterPassable) and not conforms_to(R, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, Never, type_of(function), False](function))


def tupled[A: RegisterPassable & Deinitable, B: Movable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> Tupled[NativeBinary[A, B, R, Never, type_of(function), False]] where not conforms_to(B, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, Never, type_of(function), False](function))


def tupled[A: RegisterPassable & Deinitable, B: RegisterPassable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> Tupled[NativeBinary[A, B, R, Never, type_of(function), False]] where not conforms_to(R, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, Never, type_of(function), False](function))


def tupled[A: RegisterPassable & Deinitable, B: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> Tupled[NativeBinary[A, B, R, Never, type_of(function), False]]:
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, Never, type_of(function), False](function))


def tupled[A: Movable & Deinitable, B: Movable & Deinitable, //](
    function: def(var A, var B) thin
) -> Tupled[NativeBinary[A, B, type_of(None), Never, type_of(function), False]]:
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, type_of(None), Never, type_of(function), False](function))


def tupled[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, q: ImmOrigin, //](
    ref[q] function: def(var A, var B) raises E thin -> R
) -> Tupled[NativeBinary[A, B, R, E, type_of(function), True]]:
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.
        E: The native error type.
        q: The temporary pointer admission borrow's origin.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, E, type_of(function), True](function))


def tupled[A: Movable & Deinitable, B: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> Tupled[NativeBinary[A, B, R, E, type_of(function), True]] where not conforms_to(A, RegisterPassable) and not conforms_to(B, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.
        E: The native error type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, E, type_of(function), True](function))


def tupled[A: Movable & Deinitable, B: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> Tupled[NativeBinary[A, B, R, E, type_of(function), True]] where not conforms_to(A, RegisterPassable) and not conforms_to(R, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.
        E: The native error type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, E, type_of(function), True](function))


def tupled[A: Movable & Deinitable, B: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> Tupled[NativeBinary[A, B, R, E, type_of(function), True]] where not conforms_to(A, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.
        E: The native error type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, E, type_of(function), True](function))


def tupled[A: RegisterPassable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> Tupled[NativeBinary[A, B, R, E, type_of(function), True]] where not conforms_to(B, RegisterPassable) and not conforms_to(R, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.
        E: The native error type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, E, type_of(function), True](function))


def tupled[A: RegisterPassable & Deinitable, B: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> Tupled[NativeBinary[A, B, R, E, type_of(function), True]] where not conforms_to(B, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.
        E: The native error type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, E, type_of(function), True](function))


def tupled[A: RegisterPassable & Deinitable, B: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> Tupled[NativeBinary[A, B, R, E, type_of(function), True]] where not conforms_to(R, RegisterPassable):
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.
        E: The native error type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, E, type_of(function), True](function))


def tupled[A: RegisterPassable & Deinitable, B: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> Tupled[NativeBinary[A, B, R, E, type_of(function), True]]:
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The native result type.
        E: The native error type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, R, E, type_of(function), True](function))


def tupled[A: Movable & Deinitable, B: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin
) -> Tupled[NativeBinary[A, B, type_of(None), E, type_of(function), True]]:
    """Adapt a plain binary function or stored thin pointer to one owned pair.

    The pointer is stored without invoking it. Native signature admission
    delegates to the same binary library-callable wrapper.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        E: The native error type.

    Args:
        function: The binary native function or stored pointer.

    Returns:
        A `Tupled` callable consuming the pair's two elements.
    """
    return tupled(NativeBinary[A, B, type_of(None), E, type_of(function), True](function))


# --- end tupled native admission ---
