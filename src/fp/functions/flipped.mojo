"""Swap the first two arguments of a binary callable or a native function."""
from std.builtin.rebind import downcast, rebind_var
from fp.callables.protocols import BinaryContract, Binary, MutableBinary, OnceBinary
from fp.callables.invoke import call_once, call_repeated, RepeatableBinary


@fieldwise_init
struct Flipped[F: BinaryContract & Movable & Deinitable](
    Binary where conforms_to(F, Binary),
    MutableBinary where conforms_to(F, Binary) or conforms_to(F, MutableBinary),
    OnceBinary, Copyable where conforms_to(F, Copyable)
):
    """A binary callable called with its two arguments swapped, returned by `flip`.

    It has the receiver modes of the callable it wraps.

    Parameters:
        F: The wrapped callable's type, a `Binary`, `MutableBinary` or `OnceBinary`.
    """
    comptime First = Self.F.Second
    comptime Second = Self.F.First
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    var _function: Self.F

    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Call the wrapped callable with the arguments swapped, reading it.

        Args:
            first: The flipped callable's first argument, passed second.
            second: The flipped callable's second argument, passed first.

        Returns:
            The wrapped callable's result.

        Raises:
            The wrapped callable's error, unchanged.
        """
        comptime assert conforms_to(Self.F, Binary), "flip: a shared call requires a Binary"
        comptime B = downcast[Self.F, Binary]
        return rebind_var[Self.Out](rebind[B](self._function).call(
            rebind_var[B.First](second^), rebind_var[B.Second](first^)))

    def call_mut(mut self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Call the wrapped callable with the arguments swapped and exclusive access.

        Args:
            first: The flipped callable's first argument, passed second.
            second: The flipped callable's second argument, passed first.

        Returns:
            The wrapped callable's result.

        Raises:
            The wrapped callable's error, unchanged.
        """
        comptime assert RepeatableBinary[Self.F], "flip: a repeated call requires a shared or mutable Binary"
        return call_repeated(self._function, second^, first^)

    def call_once(deinit self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Call the wrapped callable once with the arguments swapped, consuming it.

        Args:
            first: The flipped callable's first argument, passed second.
            second: The flipped callable's second argument, passed first.

        Returns:
            The wrapped callable's result.

        Raises:
            The wrapped callable's error, unchanged.
        """
        return call_once(self._function^, second^, first^)

    def __call__(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """Call the wrapped callable with the arguments swapped, as `call` does.

        Args:
            first: The flipped callable's first argument, passed second.
            second: The flipped callable's second argument, passed first.

        Returns:
            The wrapped callable's result.

        Raises:
            The wrapped callable's error, unchanged.
        """
        return self.call(first^, second^)


comptime _Swap = AnyType

# A plain function converts to this shape where it is passed to `flip`: the two
# leading parameters owned (read parameters accept owned arguments), then any
# remaining arguments as a read pack, as in `partial`.
comptime _FlipFn[R: Movable & Deinitable, E: Movable & Deinitable, A0: Movable & Deinitable,
                 A1: Movable & Deinitable, Rs: TypeList[Trait=_Swap, ...]] = def(
    var a0: A0, var a1: A1, *args: *Rs) raises E thin -> R


@fieldwise_init
struct FlippedFunction[R: Movable & Deinitable, E: Movable & Deinitable, A0: Movable & Deinitable,
                       A1: Movable & Deinitable, Rs: TypeList[Trait=_Swap, ...]](
    Copyable, Binary where Rs.length == 0
):
    """A plain function called with its first two arguments swapped, returned by `flip`.

    `flip(f)(a, b, rest...)` calls `f(b, a, rest...)`; the remaining arguments
    are borrowed. With no remaining parameters it is also a `Binary`.

    Parameters:
        R: The function's result type.
        E: The function's error type, `Never` for a pure function.
        A0: The function's first parameter type.
        A1: The function's second parameter type.
        Rs: The types of the remaining parameters.
    """
    comptime First = Self.A1
    comptime Second = Self.A0
    comptime Out = Self.R
    comptime Error = Self.E
    var function: _FlipFn[Self.R, Self.E, Self.A0, Self.A1, Self.Rs]
    """The wrapped function."""

    def __call__(self, var first: Self.A1, var second: Self.A0, *rest: *Self.Rs) raises Self.E -> Self.R:
        """Call the function with its first two arguments swapped.

        Args:
            first: Passed as the function's second argument.
            second: Passed as the function's first argument.
            rest: The remaining arguments, borrowed and passed in order.

        Returns:
            The function's result.

        Raises:
            The function's error, unchanged.
        """
        return self._call(first^, second^, *rest)

    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        """`Binary` view: call the function with its two arguments swapped.

        Args:
            first: The first argument, passed second.
            second: The second argument, passed first.

        Returns:
            The function's result.

        Raises:
            The function's error, unchanged.
        """
        return self._call(first^, second^)

    def _call[Pack: TypeList[Trait=_Swap, ...], //](
        self, var first: Self.A1, var second: Self.A0, *rest: *Pack
    ) raises Self.E -> Self.R:
        # Pack is Rs for every caller; rebinding to the same pack-typed
        # signature lets the fixed-arity `call` forward an empty pack.
        return rebind[_FlipFn[Self.R, Self.E, Self.A0, Self.A1, Pack]](self.function)(second^, first^, *rest)


def flip[F: BinaryContract & Movable & Deinitable](var function: F) -> Flipped[F]:
    """Swap the two arguments of a binary callable, keeping its receiver modes.

    Parameters:
        F: The callable's type, a `Binary`, `MutableBinary` or `OnceBinary`.

    Args:
        function: The binary library value to flip, moved in.

    Returns:
        A `Flipped` that calls `function(second, first)`.
    """
    return Flipped[F](function^)


def flip[A0: Movable & Deinitable, A1: Movable & Deinitable, R: Movable & Deinitable,
         E: Movable & Deinitable, Rs: TypeList[Trait=_Swap, ...], //](
    function: def(var a0: A0, var a1: A1, *args: *Rs) raises E thin -> R
) -> FlippedFunction[R, E, A0, A1, Rs]:
    """Swap the first two arguments of a plain function.

    `flip(f)(a, b, rest...)` calls `f(b, a, rest...)` and keeps `f`'s error type.

    Limitations:
        `f` must be a plain function (no captures); flip a closure by writing
        another closure. Keyword arguments are not forwarded.

    Parameters:
        A0: The function's first parameter type.
        A1: The function's second parameter type.
        R: The function's result type.
        E: The function's error type, `Never` for a pure function.
        Rs: The types of the remaining parameters.

    Args:
        function: The plain function to flip.

    Returns:
        A `FlippedFunction` that calls `function(second, first, rest...)`.
    """
    return FlippedFunction[R, E, A0, A1, Rs](function)
