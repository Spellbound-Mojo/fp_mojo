"""Native functions and closures as library callable values.

A native function or closure keeps its exact signature only at a parameter of
that function type. `as_unary` admits it there and stores it as a `NativeUnary`,
a `Unary` value that every consumer of the fixed-arity protocols accepts.
`_ThinFunction` stores a plain function received through a spelled thin
signature, for the fixed-arity pipeline and composition overloads.
"""

from std.builtin.rebind import downcast, rebind, rebind_var
from std.builtin.variadics import TypeList
from .protocols import Thunk, Unary, Binary, BorrowCallable
from ._receiver import _MutableBorrow, _SharedUnaryRef
from ._views import _UnaryViewable, _BinaryViewable
from .products import _OptionalCell


# Known consumed operands retain their native convention through this projection.
# Read-only register arguments instead need an explicit TrivialRegisterPassable
# parameter at overload admission. Symbolic returns also need a register branch.
comptime _NativeOwnedArg[T: Movable & Deinitable] = downcast[T, RegisterPassable & Deinitable] if conforms_to(T, RegisterPassable) else T


comptime _Thunk[R: Movable & Deinitable] = def() -> R
comptime _RaisingThunk[R: Movable & Deinitable, E: Movable & Deinitable] = def() raises E -> R


def _call_native_thunk[R: Movable & Deinitable, E: Movable & Deinitable,
                       F: Movable & Deinitable, raising: Bool](function: F) raises E -> R:
    # --- native invocation: thunk (generated) ---
    comptime if conforms_to(R, RegisterPassable):
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and E == Never and F == def() raises Never thin -> Out:
            return rebind_var[R](rebind[def() raises Never thin -> Out](function)())
        elif raising and F == def() raises E thin -> Out:
            return rebind_var[R](rebind[def() raises E thin -> Out](function)())
        elif not raising and F == def() thin -> Out:
            comptime assert E == Never
            return rebind_var[R](rebind[def() thin -> Out](function)())
    comptime if R == type_of(None) and raising and E == Never and F == def() raises Never thin:
        _ = rebind[def() raises Never thin](function)()
        return rebind_var[R](None)
    comptime if R == type_of(None) and raising and F == def() raises E thin:
        _ = rebind[def() raises E thin](function)()
        return rebind_var[R](None)
    comptime if R == type_of(None) and not raising and F == def() thin:
        comptime assert E == Never
        _ = rebind[def() thin](function)()
        return rebind_var[R](None)
    comptime if raising and E == Never and F == def() raises Never thin -> R:
        return rebind[def() raises Never thin -> R](function)()
    comptime if raising and F == def() raises E thin -> R:
        return rebind[def() raises E thin -> R](function)()
    comptime if not raising and F == def() thin -> R:
        comptime assert E == Never
        return rebind[def() thin -> R](function)()
    comptime if R == type_of(None) and raising and E == Never:
        comptime Fn = downcast[F, def() raises Never]
        _ = rebind[Fn](function)()
        return rebind_var[R](None)
    elif R == type_of(None) and raising:
        comptime Fn = downcast[F, def() raises E]
        _ = rebind[Fn](function)()
        return rebind_var[R](None)
    elif R == type_of(None) and not raising:
        comptime assert E == Never
        comptime Fn = downcast[F, def()]
        _ = rebind[Fn](function)()
        return rebind_var[R](None)
    elif raising and E == Never:
        comptime Fn = downcast[F, def() raises Never -> R]
        return rebind[Fn](function)()
    elif raising:
        comptime Fn = downcast[F, def() raises E -> R]
        return rebind[Fn](function)()
    elif True:
        comptime assert E == Never
        comptime Fn = downcast[F, def() -> R]
        return rebind[Fn](function)()
    # --- end native invocation ---


struct _NativeThunk[R: Movable & Deinitable, E: Movable & Deinitable,
                    F: Movable & Deinitable, raising: Bool](Thunk, Copyable where conforms_to(F, Copyable)):
    # Own the exact thin function pointer when a family retains the factory.
    comptime Out = Self.R
    comptime Error = Self.E
    var _function: _OptionalCell[Self.F]
    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    def call(self) raises Self.E -> Self.R:
        return _call_native_thunk[Self.R, Self.E, Self.F, Self.raising](self._function.value())


@fieldwise_init
struct _NativeThunkRef[R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Thunk, ImplicitlyCopyable):
    # The borrowed view retains the exact callback origin.
    var function: Pointer[Self.F, Self.o]
    comptime Out = Self.R
    comptime Error = Self.X
    def call(self) raises Self.Error -> Self.Out:
        return _call_native_thunk[Self.R, Self.X, Self.F, Self.raising](self.function[])


comptime _Binary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable] = def(var A, var B) -> R
comptime _RaisingBinary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A, var B) raises X -> R


def _call_native_binary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                        X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](
    function: F, var first: A, var second: B
) raises X -> R:
    # --- native invocation: binary (generated) ---
    comptime if not conforms_to(A, RegisterPassable & Deinitable) and conforms_to(B, RegisterPassable & Deinitable) and R == type_of(None):
        comptime Arg1 = downcast[B, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var A, var Arg1) raises Never thin:
            _ = rebind[def(var A, var Arg1) raises Never thin](function)(first^, rebind_var[Arg1](second^))
            return rebind_var[R](None)
        elif raising and F == def(var A, var Arg1) raises X thin:
            _ = rebind[def(var A, var Arg1) raises X thin](function)(first^, rebind_var[Arg1](second^))
            return rebind_var[R](None)
        elif not raising and F == def(var A, var Arg1) thin:
            comptime assert X == Never
            _ = rebind[def(var A, var Arg1) thin](function)(first^, rebind_var[Arg1](second^))
            return rebind_var[R](None)
    comptime if conforms_to(A, RegisterPassable & Deinitable) and not conforms_to(B, RegisterPassable & Deinitable) and R == type_of(None):
        comptime Arg0 = downcast[A, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var Arg0, var B) raises Never thin:
            _ = rebind[def(var Arg0, var B) raises Never thin](function)(rebind_var[Arg0](first^), second^)
            return rebind_var[R](None)
        elif raising and F == def(var Arg0, var B) raises X thin:
            _ = rebind[def(var Arg0, var B) raises X thin](function)(rebind_var[Arg0](first^), second^)
            return rebind_var[R](None)
        elif not raising and F == def(var Arg0, var B) thin:
            comptime assert X == Never
            _ = rebind[def(var Arg0, var B) thin](function)(rebind_var[Arg0](first^), second^)
            return rebind_var[R](None)
    comptime if conforms_to(A, RegisterPassable & Deinitable) and conforms_to(B, RegisterPassable & Deinitable) and R == type_of(None):
        comptime Arg0 = downcast[A, RegisterPassable & Deinitable]
        comptime Arg1 = downcast[B, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var Arg0, var Arg1) raises Never thin:
            _ = rebind[def(var Arg0, var Arg1) raises Never thin](function)(rebind_var[Arg0](first^), rebind_var[Arg1](second^))
            return rebind_var[R](None)
        elif raising and F == def(var Arg0, var Arg1) raises X thin:
            _ = rebind[def(var Arg0, var Arg1) raises X thin](function)(rebind_var[Arg0](first^), rebind_var[Arg1](second^))
            return rebind_var[R](None)
        elif not raising and F == def(var Arg0, var Arg1) thin:
            comptime assert X == Never
            _ = rebind[def(var Arg0, var Arg1) thin](function)(rebind_var[Arg0](first^), rebind_var[Arg1](second^))
            return rebind_var[R](None)
    comptime if not conforms_to(A, RegisterPassable & Deinitable) and not conforms_to(B, RegisterPassable & Deinitable) and conforms_to(R, RegisterPassable):
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var A, var B) raises Never thin -> Out:
            return rebind_var[R](rebind[def(var A, var B) raises Never thin -> Out](function)(first^, second^))
        elif raising and F == def(var A, var B) raises X thin -> Out:
            return rebind_var[R](rebind[def(var A, var B) raises X thin -> Out](function)(first^, second^))
        elif not raising and F == def(var A, var B) thin -> Out:
            comptime assert X == Never
            return rebind_var[R](rebind[def(var A, var B) thin -> Out](function)(first^, second^))
    comptime if not conforms_to(A, RegisterPassable & Deinitable) and conforms_to(B, RegisterPassable & Deinitable) and not conforms_to(R, RegisterPassable):
        comptime Arg1 = downcast[B, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var A, var Arg1) raises Never thin -> R:
            return rebind_var[R](rebind[def(var A, var Arg1) raises Never thin -> R](function)(first^, rebind_var[Arg1](second^)))
        elif raising and F == def(var A, var Arg1) raises X thin -> R:
            return rebind_var[R](rebind[def(var A, var Arg1) raises X thin -> R](function)(first^, rebind_var[Arg1](second^)))
        elif not raising and F == def(var A, var Arg1) thin -> R:
            comptime assert X == Never
            return rebind_var[R](rebind[def(var A, var Arg1) thin -> R](function)(first^, rebind_var[Arg1](second^)))
    comptime if not conforms_to(A, RegisterPassable & Deinitable) and conforms_to(B, RegisterPassable & Deinitable) and conforms_to(R, RegisterPassable):
        comptime Arg1 = downcast[B, RegisterPassable & Deinitable]
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var A, var Arg1) raises Never thin -> Out:
            return rebind_var[R](rebind[def(var A, var Arg1) raises Never thin -> Out](function)(first^, rebind_var[Arg1](second^)))
        elif raising and F == def(var A, var Arg1) raises X thin -> Out:
            return rebind_var[R](rebind[def(var A, var Arg1) raises X thin -> Out](function)(first^, rebind_var[Arg1](second^)))
        elif not raising and F == def(var A, var Arg1) thin -> Out:
            comptime assert X == Never
            return rebind_var[R](rebind[def(var A, var Arg1) thin -> Out](function)(first^, rebind_var[Arg1](second^)))
    comptime if conforms_to(A, RegisterPassable & Deinitable) and not conforms_to(B, RegisterPassable & Deinitable) and not conforms_to(R, RegisterPassable):
        comptime Arg0 = downcast[A, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var Arg0, var B) raises Never thin -> R:
            return rebind_var[R](rebind[def(var Arg0, var B) raises Never thin -> R](function)(rebind_var[Arg0](first^), second^))
        elif raising and F == def(var Arg0, var B) raises X thin -> R:
            return rebind_var[R](rebind[def(var Arg0, var B) raises X thin -> R](function)(rebind_var[Arg0](first^), second^))
        elif not raising and F == def(var Arg0, var B) thin -> R:
            comptime assert X == Never
            return rebind_var[R](rebind[def(var Arg0, var B) thin -> R](function)(rebind_var[Arg0](first^), second^))
    comptime if conforms_to(A, RegisterPassable & Deinitable) and not conforms_to(B, RegisterPassable & Deinitable) and conforms_to(R, RegisterPassable):
        comptime Arg0 = downcast[A, RegisterPassable & Deinitable]
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var Arg0, var B) raises Never thin -> Out:
            return rebind_var[R](rebind[def(var Arg0, var B) raises Never thin -> Out](function)(rebind_var[Arg0](first^), second^))
        elif raising and F == def(var Arg0, var B) raises X thin -> Out:
            return rebind_var[R](rebind[def(var Arg0, var B) raises X thin -> Out](function)(rebind_var[Arg0](first^), second^))
        elif not raising and F == def(var Arg0, var B) thin -> Out:
            comptime assert X == Never
            return rebind_var[R](rebind[def(var Arg0, var B) thin -> Out](function)(rebind_var[Arg0](first^), second^))
    comptime if conforms_to(A, RegisterPassable & Deinitable) and conforms_to(B, RegisterPassable & Deinitable) and not conforms_to(R, RegisterPassable):
        comptime Arg0 = downcast[A, RegisterPassable & Deinitable]
        comptime Arg1 = downcast[B, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var Arg0, var Arg1) raises Never thin -> R:
            return rebind_var[R](rebind[def(var Arg0, var Arg1) raises Never thin -> R](function)(rebind_var[Arg0](first^), rebind_var[Arg1](second^)))
        elif raising and F == def(var Arg0, var Arg1) raises X thin -> R:
            return rebind_var[R](rebind[def(var Arg0, var Arg1) raises X thin -> R](function)(rebind_var[Arg0](first^), rebind_var[Arg1](second^)))
        elif not raising and F == def(var Arg0, var Arg1) thin -> R:
            comptime assert X == Never
            return rebind_var[R](rebind[def(var Arg0, var Arg1) thin -> R](function)(rebind_var[Arg0](first^), rebind_var[Arg1](second^)))
    comptime if conforms_to(A, RegisterPassable & Deinitable) and conforms_to(B, RegisterPassable & Deinitable) and conforms_to(R, RegisterPassable):
        comptime Arg0 = downcast[A, RegisterPassable & Deinitable]
        comptime Arg1 = downcast[B, RegisterPassable & Deinitable]
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and X == Never and F == def(var Arg0, var Arg1) raises Never thin -> Out:
            return rebind_var[R](rebind[def(var Arg0, var Arg1) raises Never thin -> Out](function)(rebind_var[Arg0](first^), rebind_var[Arg1](second^)))
        elif raising and F == def(var Arg0, var Arg1) raises X thin -> Out:
            return rebind_var[R](rebind[def(var Arg0, var Arg1) raises X thin -> Out](function)(rebind_var[Arg0](first^), rebind_var[Arg1](second^)))
        elif not raising and F == def(var Arg0, var Arg1) thin -> Out:
            comptime assert X == Never
            return rebind_var[R](rebind[def(var Arg0, var Arg1) thin -> Out](function)(rebind_var[Arg0](first^), rebind_var[Arg1](second^)))
    comptime if R == type_of(None) and raising and X == Never and F == def(var A, var B) raises Never thin:
        _ = rebind[def(var A, var B) raises Never thin](function)(first^, second^)
        return rebind_var[R](None)
    comptime if R == type_of(None) and raising and F == def(var A, var B) raises X thin:
        _ = rebind[def(var A, var B) raises X thin](function)(first^, second^)
        return rebind_var[R](None)
    comptime if R == type_of(None) and not raising and F == def(var A, var B) thin:
        comptime assert X == Never
        _ = rebind[def(var A, var B) thin](function)(first^, second^)
        return rebind_var[R](None)
    comptime if raising and X == Never and F == def(var A, var B) raises Never thin -> R:
        return rebind[def(var A, var B) raises Never thin -> R](function)(first^, second^)
    comptime if raising and F == def(var A, var B) raises X thin -> R:
        return rebind[def(var A, var B) raises X thin -> R](function)(first^, second^)
    comptime if not raising and F == def(var A, var B) thin -> R:
        comptime assert X == Never
        return rebind[def(var A, var B) thin -> R](function)(first^, second^)
    comptime if R == type_of(None) and raising and X == Never:
        comptime Fn = downcast[F, def(var A, var B) raises Never]
        _ = rebind[Fn](function)(first^, second^)
        return rebind_var[R](None)
    elif R == type_of(None) and raising:
        comptime Fn = downcast[F, def(var A, var B) raises X]
        _ = rebind[Fn](function)(first^, second^)
        return rebind_var[R](None)
    elif R == type_of(None) and not raising:
        comptime assert X == Never
        comptime Fn = downcast[F, def(var A, var B)]
        _ = rebind[Fn](function)(first^, second^)
        return rebind_var[R](None)
    elif raising and X == Never:
        comptime Fn = downcast[F, def(var A, var B) raises Never -> R]
        return rebind[Fn](function)(first^, second^)
    elif raising:
        comptime Fn = downcast[F, def(var A, var B) raises X -> R]
        return rebind[Fn](function)(first^, second^)
    elif True:
        comptime assert X == Never
        comptime Fn = downcast[F, def(var A, var B) -> R]
        return rebind[Fn](function)(first^, second^)
    # --- end native invocation ---


@fieldwise_init
struct _NativeBinaryRef[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                        X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Binary, ImplicitlyCopyable):
    """Borrow the native callback with its captures and origins intact."""
    comptime First = Self.A
    comptime Second = Self.B
    comptime Out = Self.R
    comptime Error = Self.X
    var function: Pointer[Self.F, Self.o]
    def call(self, var first: Self.A, var second: Self.B) raises Self.X -> Self.R:
        return _call_native_binary[Self.A, Self.B, Self.R, Self.X, Self.F, Self.raising](self.function[], first^, second^)


@fieldwise_init
struct NativeBinary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                    E: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](
    Binary, _BinaryViewable, Copyable where conforms_to(F, Copyable),
    ImplicitlyCopyable where conforms_to(F, ImplicitlyCopyable),
):
    """A native binary callback stored as a `Binary` value, made by `as_binary`.

    The factory accepts plain functions and stored thin pointers. Named
    adapters can be reused by shared borrow in supported binary iteration
    operations. An explicit move transfers the adapter to a consumer.
    Argument, result and error types remain exact, including embedded origins.
    Copyability follows the stored native callable.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The native error type; `Never` when no error can be raised.
        F: The exact stored callable type.
        raising: Whether the native signature declares a raised error.
    """
    comptime First = Self.A
    comptime Second = Self.B
    comptime Out = Self.R
    comptime Error = Self.E
    var _function: _OptionalCell[Self.F]

    def __init__(out self, var function: Self.F):
        """Store the native callable without invoking it.

        Args:
            function: The native callable, moved into the adapter.
        """
        self._function = Optional(function^)

    def function(ref self) -> ref[self._function._value] Self.F:
        """Borrow the stored native callable with the receiver's mutability.

        Returns:
            A reference retaining the stored callable's exact type and origins.
        """
        return self._function.value()

    def into_function(deinit self) -> Self.F:
        """Move the native callable out, consuming the adapter.

        Returns:
            The original native callable, without invoking or copying it.
        """
        return self._function.take()

    def call(self, var first: Self.A, var second: Self.B) raises Self.E -> Self.R:
        """Call the stored function with two owned arguments.

        Args:
            first: The first argument, consumed.
            second: The second argument, consumed.

        Returns:
            The native callback's result, unchanged.

        Raises:
            The native callback's exact error type.
        """
        return _call_native_binary[Self.A, Self.B, Self.R, Self.E, Self.F, Self.raising](self._function.value(), first^, second^)

    def __call__(self, var first: Self.A, var second: Self.B) raises Self.E -> Self.R:
        """Call the adapter directly, as `call` does.

        Args:
            first: The first argument, consumed.
            second: The second argument, consumed.

        Returns:
            The native callback's result, unchanged.

        Raises:
            The native callback's exact error type.
        """
        return self.call(first^, second^)


# Preserve existing signature spellings while sharing the public storage owner.
comptime _NativeBinary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                      E: Movable & Deinitable, F: Movable & Deinitable, raising: Bool] = NativeBinary[A, B, R, E, F, raising]


struct BinarySignature[A: Movable & Deinitable, B: Movable & Deinitable,
                       R: Movable & Deinitable, E: Movable & Deinitable = Never]:
    """Select a binary signature before capturing a native closure.

    `BinarySignature[A, B, R].capture(closure)` infers the closure's concrete
    type and returns a `NativeBinary`. Supply `E` for a raising callback.
    The default `Never` accepts both pure and explicitly `raises Never`
    signatures. Use `type_of(None)` for a procedure with no return value;
    an explicit `NoneType` result remains distinct.

    Signature selection precedes callback admission, so rejected conventions
    do not require inference of the input, result or error types from the
    callback. No callback runs during capture. Ownership, copyability and
    embedded origins remain those of the stored callable.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The raised error type, defaulting to `Never`.
    """
    # --- native binary capture (generated) ---
    @staticmethod
    def capture[F: _Binary[Self.A, Self.B, Self.R]](var function: F) -> NativeBinary[Self.A, Self.B, Self.R, Never, F, False] where Self.E == Never and Self.R != type_of(None):
        """Capture a callback with the selected signature without invoking it.

        Parameters:
            F: The callback's exact native type, inferred at this boundary.

        Args:
            function: The callback, moved into the adapter with its captures.

        Returns:
            A `NativeBinary` preserving the callback's types and ownership.
        """
        return NativeBinary[Self.A, Self.B, Self.R, Never, F, False](function^)

    @staticmethod
    def capture[F: def(var Self.A, var Self.B)](var function: F) -> NativeBinary[Self.A, Self.B, Self.R, Never, F, False] where Self.E == Never and Self.R == type_of(None):
        """Capture a callback with the selected signature without invoking it.

        Parameters:
            F: The callback's exact native type, inferred at this boundary.

        Args:
            function: The callback, moved into the adapter with its captures.

        Returns:
            A `NativeBinary` preserving the callback's types and ownership.
        """
        return NativeBinary[Self.A, Self.B, Self.R, Never, F, False](function^)

    @staticmethod
    def capture[F: _RaisingBinary[Self.A, Self.B, Self.R, Self.E]](var function: F) -> NativeBinary[Self.A, Self.B, Self.R, Self.E, F, True] where Self.R != type_of(None):
        """Capture a callback with the selected signature without invoking it.

        Parameters:
            F: The callback's exact native type, inferred at this boundary.

        Args:
            function: The callback, moved into the adapter with its captures.

        Returns:
            A `NativeBinary` preserving the callback's types and ownership.
        """
        return NativeBinary[Self.A, Self.B, Self.R, Self.E, F, True](function^)

    @staticmethod
    def capture[F: def(var Self.A, var Self.B) raises Self.E](var function: F) -> NativeBinary[Self.A, Self.B, Self.R, Self.E, F, True] where Self.R == type_of(None):
        """Capture a callback with the selected signature without invoking it.

        Parameters:
            F: The callback's exact native type, inferred at this boundary.

        Args:
            function: The callback, moved into the adapter with its captures.

        Returns:
            A `NativeBinary` preserving the callback's types and ownership.
        """
        return NativeBinary[Self.A, Self.B, Self.R, Self.E, F, True](function^)

    # --- end native binary capture ---


comptime _Unary[A: Movable & Deinitable, R: Movable & Deinitable] = def(var A) -> R


comptime _RaisingUnary[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable] = def(var A) raises E -> R




# Factory parameter names are part of native conformance recovery on Mojo 1.1.
# Iterator factories introduce T/U (including an Optional result), while pipeline
# promotion introduces A/R. Keep those admission spellings; invocation is shared.
comptime _LazyUnary[T: Movable & Deinitable, U: Movable & Deinitable] = def(var T) -> U
comptime _LazyOptional[T: Movable & Deinitable, U: Movable & Deinitable] = def(var T) -> Optional[U]


def _call_native_register_void[A: TrivialRegisterPassable, E: Movable & Deinitable,
                               F: Movable & Deinitable, raising: Bool](
    function: F, value: A
) raises E -> type_of(None):
    # A must retain its register bound while the native signature is rebuilt.
    # A generic Movable argument instead describes an argument passed in memory.
    comptime if raising and E == Never:
        comptime if F == def(A) raises Never thin:
            rebind[def(A) raises Never thin](function)(value)
        else:
            comptime Fn = downcast[F, def(A) raises Never]
            rebind[Fn](function)(value)
    elif raising:
        comptime if F == def(A) raises E thin:
            rebind[def(A) raises E thin](function)(value)
        else:
            comptime Fn = downcast[F, def(A) raises E]
            rebind[Fn](function)(value)
    else:
        comptime assert E == Never
        comptime if F == def(A) thin:
            rebind[def(A) thin](function)(value)
        else:
            comptime Fn = downcast[F, def(A)]
            rebind[Fn](function)(value)
    return None


def _call_native_never[A: Movable, R: Movable, F: Movable & Deinitable](
    function: F, var value: A
) raises Never -> R:
    # Keep the literal Never signature; generic E loses its native witness.
    # Movable inputs/results also support one-stage pipe without narrowing it.
    comptime if F == def(var A) raises Never thin -> R:
        return rebind[def(var A) raises Never thin -> R](function)(value^)
    elif R == type_of(None):
        comptime if conforms_to(A, TrivialRegisterPassable):
            comptime Arg = downcast[A, TrivialRegisterPassable]
            comptime if F == def(Arg) raises Never thin or conforms_to(F, def(Arg) raises Never):
                _call_native_register_void[Arg, Never, F, True](function, rebind_var[Arg](value))
                return rebind_var[R](None)
        comptime if F == def(var A) raises Never thin:
            _ = rebind[def(var A) raises Never thin](function)(value^)
        else:
            comptime Fn = downcast[F, def(var A) raises Never]
            _ = rebind[Fn](function)(value^)
        return rebind_var[R](None)
    else:
        comptime Fn = downcast[F, def(var A) raises Never -> R]
        return rebind[Fn](function)(value^)


def _call_native[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                 F: Movable & Deinitable, raising: Bool](function: F, var value: A) raises E -> R:
    # --- native invocation: unary (generated) ---
    comptime if R == type_of(None) and conforms_to(A, TrivialRegisterPassable):
        comptime Arg = downcast[A, TrivialRegisterPassable]
        comptime if raising and E == Never:
            comptime if F == def(Arg) raises Never thin or conforms_to(F, def(Arg) raises Never):
                _call_native_register_void[Arg, Never, F, True](function, rebind_var[Arg](value))
                return rebind_var[R](None)
        elif raising:
            comptime if F == def(Arg) raises E thin or conforms_to(F, def(Arg) raises E):
                _call_native_register_void[Arg, E, F, True](function, rebind_var[Arg](value))
                return rebind_var[R](None)
        else:
            comptime if F == def(Arg) thin or conforms_to(F, def(Arg)):
                _call_native_register_void[Arg, Never, F, False](function, rebind_var[Arg](value))
                return rebind_var[R](None)
    comptime if conforms_to(A, RegisterPassable & Deinitable) and R == type_of(None):
        comptime Arg0 = downcast[A, RegisterPassable & Deinitable]
        comptime if raising and E == Never and F == def(var Arg0) raises Never thin:
            _ = rebind[def(var Arg0) raises Never thin](function)(rebind_var[Arg0](value^))
            return rebind_var[R](None)
        elif raising and F == def(var Arg0) raises E thin:
            _ = rebind[def(var Arg0) raises E thin](function)(rebind_var[Arg0](value^))
            return rebind_var[R](None)
        elif not raising and F == def(var Arg0) thin:
            comptime assert E == Never
            _ = rebind[def(var Arg0) thin](function)(rebind_var[Arg0](value^))
            return rebind_var[R](None)
    comptime if not conforms_to(A, RegisterPassable & Deinitable) and conforms_to(R, RegisterPassable):
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and E == Never and F == def(var A) raises Never thin -> Out:
            return rebind_var[R](rebind[def(var A) raises Never thin -> Out](function)(value^))
        elif raising and F == def(var A) raises E thin -> Out:
            return rebind_var[R](rebind[def(var A) raises E thin -> Out](function)(value^))
        elif not raising and F == def(var A) thin -> Out:
            comptime assert E == Never
            return rebind_var[R](rebind[def(var A) thin -> Out](function)(value^))
    comptime if conforms_to(A, RegisterPassable & Deinitable) and not conforms_to(R, RegisterPassable):
        comptime Arg0 = downcast[A, RegisterPassable & Deinitable]
        comptime if raising and E == Never and F == def(var Arg0) raises Never thin -> R:
            return rebind_var[R](rebind[def(var Arg0) raises Never thin -> R](function)(rebind_var[Arg0](value^)))
        elif raising and F == def(var Arg0) raises E thin -> R:
            return rebind_var[R](rebind[def(var Arg0) raises E thin -> R](function)(rebind_var[Arg0](value^)))
        elif not raising and F == def(var Arg0) thin -> R:
            comptime assert E == Never
            return rebind_var[R](rebind[def(var Arg0) thin -> R](function)(rebind_var[Arg0](value^)))
    comptime if conforms_to(A, RegisterPassable & Deinitable) and conforms_to(R, RegisterPassable):
        comptime Arg0 = downcast[A, RegisterPassable & Deinitable]
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and E == Never and F == def(var Arg0) raises Never thin -> Out:
            return rebind_var[R](rebind[def(var Arg0) raises Never thin -> Out](function)(rebind_var[Arg0](value^)))
        elif raising and F == def(var Arg0) raises E thin -> Out:
            return rebind_var[R](rebind[def(var Arg0) raises E thin -> Out](function)(rebind_var[Arg0](value^)))
        elif not raising and F == def(var Arg0) thin -> Out:
            comptime assert E == Never
            return rebind_var[R](rebind[def(var Arg0) thin -> Out](function)(rebind_var[Arg0](value^)))
    comptime if R == type_of(None) and raising and E == Never and F == def(var A) raises Never thin:
        _ = rebind[def(var A) raises Never thin](function)(value^)
        return rebind_var[R](None)
    comptime if R == type_of(None) and raising and F == def(var A) raises E thin:
        _ = rebind[def(var A) raises E thin](function)(value^)
        return rebind_var[R](None)
    comptime if R == type_of(None) and not raising and F == def(var A) thin:
        comptime assert E == Never
        _ = rebind[def(var A) thin](function)(value^)
        return rebind_var[R](None)
    comptime if raising and E == Never and F == def(var A) raises Never thin -> R:
        return rebind[def(var A) raises Never thin -> R](function)(value^)
    comptime if raising and F == def(var A) raises E thin -> R:
        return rebind[def(var A) raises E thin -> R](function)(value^)
    comptime if not raising and F == def(var A) thin -> R:
        comptime assert E == Never
        return rebind[def(var A) thin -> R](function)(value^)
    comptime if R == type_of(None) and raising and E == Never:
        comptime Fn = downcast[F, def(var A) raises Never]
        _ = rebind[Fn](function)(value^)
        return rebind_var[R](None)
    elif R == type_of(None) and raising:
        comptime Fn = downcast[F, def(var A) raises E]
        _ = rebind[Fn](function)(value^)
        return rebind_var[R](None)
    elif R == type_of(None) and not raising:
        comptime assert E == Never
        comptime Fn = downcast[F, def(var A)]
        _ = rebind[Fn](function)(value^)
        return rebind_var[R](None)
    elif raising and E == Never:
        comptime Fn = downcast[F, def(var A) raises Never -> R]
        return rebind[Fn](function)(value^)
    elif raising:
        comptime Fn = downcast[F, def(var A) raises E -> R]
        return rebind[Fn](function)(value^)
    elif True:
        comptime assert E == Never
        comptime Fn = downcast[F, def(var A) -> R]
        return rebind[Fn](function)(value^)
    # --- end native invocation ---


@fieldwise_init
struct NativeUnary[A: Movable & Deinitable, R: Movable & Deinitable,
                   E: Movable & Deinitable, F: Movable & Deinitable,
                   raising: Bool](Unary, _UnaryViewable, Copyable where conforms_to(F, Copyable),
                                  ImplicitlyCopyable where conforms_to(F, ImplicitlyCopyable)):
    """A native function or closure stored as a `Unary` value, made by `as_unary`.

    Named adapters can be reused in Pipeline and Result callbacks through a
    shared borrow of their stored function. Deferred operations retain that
    borrow; an explicit move transfers the adapter and its captures.
    It is `Copyable` when the stored function is. The Mojo 1.1 O3 measurements
    matched direct calls; that performance result is not yet requalified for 1.2.

    Parameters:
        A: The argument type.
        R: The result type.
        E: The error type; `Never` for a function that does not raise.
        F: The stored function's type.
        raising: Whether the stored function raises.
    """
    # Mojo 1.2 loses native function witnesses in direct generic fields. The
    # existing inline cell preserves the exact F, captures and conditional copy
    # behavior. It is always occupied until into_function consumes it.
    var _function: _OptionalCell[Self.F]
    comptime Arg = Self.A
    comptime Out = Self.R
    comptime Error = Self.E

    def __init__(out self, var function: Self.F):
        """Move a native function or closure into the callable.

        Args:
            function: The native callable, consumed without copying or calling it.
        """
        self._function = Optional(function^)

    comptime _View[o: ImmOrigin] = _SharedUnaryRef[Self, o]

    def _unary_view[o: ImmOrigin](ref[o] self) -> Self._View[o]:
        return Self._View[o](Pointer(to=self))

    def function(ref self) -> ref[self._function._value] Self.F:
        """Borrow the stored native function with the receiver's mutability.

        Returns:
            A reference to the exact native callable, retaining its captures.
        """
        return self._function.value()

    def into_function(deinit self) -> Self.F:
        """Move the stored function out, consuming the callable.

        Returns:
            The original native callable, moved out without copying or calling it.
        """
        return self._function.take()

    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Call the stored function.

        Args:
            arg: The argument, consumed.

        Returns:
            The function's result.

        Raises:
            The function's error, unchanged; nothing when it does not raise.
        """
        return _call_native[Self.A, Self.R, Self.E, Self.F, Self.raising](self._function.value(), arg^)

    def __call__(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Call the stored function directly, as `call` does.

        Args:
            arg: The argument, consumed.

        Returns:
            The function's result.

        Raises:
            The function's error, unchanged; nothing when it does not raise.
        """
        return self.call(arg^)


@fieldwise_init
struct _NativeUnaryRef[A: Movable & Deinitable, R: Movable & Deinitable,
                       E: Movable & Deinitable, F: Movable & Deinitable,
                       raising: Bool, origin: ImmOrigin](Unary, ImplicitlyCopyable):
    # A borrowed native def. Generic forwarding holds a native function by
    # reference and cannot copy it; the call is the same as NativeUnary's.
    var function: Pointer[Self.F, Self.origin]
    comptime Arg = Self.A
    comptime Out = Self.R
    comptime Error = Self.E
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return _call_native[Self.A, Self.R, Self.E, Self.F, Self.raising](self.function[], arg^)


def as_unary[A: Movable & Deinitable, R: Movable & Deinitable, //,
              F: _Unary[A, R]](var function: F) -> NativeUnary[A, R, Never, F, False]:
    """Store a native function or closure as a `Unary` value.

    This moves the callable in and never calls or copies it. Most entry points
    take native functions and closures without it. Use it to store a callback
    as a library callable, compose closures, or satisfy a generic `Unary` contract.
    `fp.functions` re-exports it.

    Parameters:
        A: The argument type.
        R: The result type.
        F: The function's type: a plain function or a closure taking one owned argument.

    Args:
        function: The function or closure, moved in.

    Returns:
        A `NativeUnary` holding `function`, callable with `call` or directly.
    """
    return NativeUnary[A, R, Never, F, False](function^)


def as_unary[A: Movable & Deinitable, R: Movable & Deinitable,
              E: Movable & Deinitable, //,
              F: _RaisingUnary[A, R, E]](var function: F) -> NativeUnary[A, R, E, F, True]:
    """Store a raising native function or closure, keeping its exact error type."""
    return NativeUnary[A, R, E, F, True](function^)


# --- native unary admission (generated) ---
# Preserve native pointer types and copyability. Register arguments and
# results need explicit ABI evidence; symbolic forwards borrow a pointer
# only for admission, then copy it into the existing NativeUnary owner.
# No-value signatures must be admitted literally on Mojo 1.2.
def as_unary[A: Movable & Deinitable, R: Movable & Deinitable, q: ImmOrigin, //](
    ref[q] function: def(var A) thin -> R
) -> NativeUnary[A, R, Never, type_of(function), False]:
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, R, Never, type_of(function), False](function)


def as_unary[A: Movable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A) thin -> R
) -> NativeUnary[A, R, Never, type_of(function), False] where not conforms_to(A, RegisterPassable):
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, R, Never, type_of(function), False](function)


def as_unary[A: RegisterPassable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A) thin -> R
) -> NativeUnary[A, R, Never, type_of(function), False] where not conforms_to(R, RegisterPassable):
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, R, Never, type_of(function), False](function)


def as_unary[A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A) thin -> R
) -> NativeUnary[A, R, Never, type_of(function), False]:
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, R, Never, type_of(function), False](function)


def as_unary[A: Movable & Deinitable, //](
    function: def(var A) thin
) -> NativeUnary[A, type_of(None), Never, type_of(function), False]:
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, type_of(None), Never, type_of(function), False](function)


def as_unary[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, q: ImmOrigin, //](
    ref[q] function: def(var A) raises E thin -> R
) -> NativeUnary[A, R, E, type_of(function), True]:
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, R, E, type_of(function), True](function)


def as_unary[A: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A) raises E thin -> R
) -> NativeUnary[A, R, E, type_of(function), True] where not conforms_to(A, RegisterPassable):
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, R, E, type_of(function), True](function)


def as_unary[A: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A) raises E thin -> R
) -> NativeUnary[A, R, E, type_of(function), True] where not conforms_to(R, RegisterPassable):
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, R, E, type_of(function), True](function)


def as_unary[A: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A) raises E thin -> R
) -> NativeUnary[A, R, E, type_of(function), True]:
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, R, E, type_of(function), True](function)


def as_unary[A: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A) raises E thin
) -> NativeUnary[A, type_of(None), E, type_of(function), True]:
    """Store a native pointer with its exact signature and copyability."""
    return NativeUnary[A, type_of(None), E, type_of(function), True](function)


# --- end native unary admission ---


# --- native binary admission (generated) ---
def as_binary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, q: ImmOrigin, //](
    ref[q] function: def(var A, var B) thin -> R
) -> NativeBinary[A, B, R, Never, type_of(function), False]:
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        q: The temporary admission borrow's origin, not stored in the adapter.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, Never, type_of(function), False](function)


def as_binary[A: Movable & Deinitable, B: Movable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> NativeBinary[A, B, R, Never, type_of(function), False] where not conforms_to(A, RegisterPassable) and not conforms_to(B, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, Never, type_of(function), False](function)


def as_binary[A: Movable & Deinitable, B: RegisterPassable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> NativeBinary[A, B, R, Never, type_of(function), False] where not conforms_to(A, RegisterPassable) and not conforms_to(R, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, Never, type_of(function), False](function)


def as_binary[A: Movable & Deinitable, B: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> NativeBinary[A, B, R, Never, type_of(function), False] where not conforms_to(A, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, Never, type_of(function), False](function)


def as_binary[A: RegisterPassable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> NativeBinary[A, B, R, Never, type_of(function), False] where not conforms_to(B, RegisterPassable) and not conforms_to(R, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, Never, type_of(function), False](function)


def as_binary[A: RegisterPassable & Deinitable, B: Movable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> NativeBinary[A, B, R, Never, type_of(function), False] where not conforms_to(B, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, Never, type_of(function), False](function)


def as_binary[A: RegisterPassable & Deinitable, B: RegisterPassable & Deinitable, R: Movable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> NativeBinary[A, B, R, Never, type_of(function), False] where not conforms_to(R, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, Never, type_of(function), False](function)


def as_binary[A: RegisterPassable & Deinitable, B: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, //](
    function: def(var A, var B) thin -> R
) -> NativeBinary[A, B, R, Never, type_of(function), False]:
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, Never, type_of(function), False](function)


def as_binary[A: Movable & Deinitable, B: Movable & Deinitable, //](
    function: def(var A, var B) thin
) -> NativeBinary[A, B, type_of(None), Never, type_of(function), False]:
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, type_of(None), Never, type_of(function), False](function)


def as_binary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, q: ImmOrigin, //](
    ref[q] function: def(var A, var B) raises E thin -> R
) -> NativeBinary[A, B, R, E, type_of(function), True]:
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The native error type.
        q: The temporary admission borrow's origin, not stored in the adapter.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, E, type_of(function), True](function)


def as_binary[A: Movable & Deinitable, B: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> NativeBinary[A, B, R, E, type_of(function), True] where not conforms_to(A, RegisterPassable) and not conforms_to(B, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The native error type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, E, type_of(function), True](function)


def as_binary[A: Movable & Deinitable, B: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> NativeBinary[A, B, R, E, type_of(function), True] where not conforms_to(A, RegisterPassable) and not conforms_to(R, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The native error type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, E, type_of(function), True](function)


def as_binary[A: Movable & Deinitable, B: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> NativeBinary[A, B, R, E, type_of(function), True] where not conforms_to(A, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The native error type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, E, type_of(function), True](function)


def as_binary[A: RegisterPassable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> NativeBinary[A, B, R, E, type_of(function), True] where not conforms_to(B, RegisterPassable) and not conforms_to(R, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The native error type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, E, type_of(function), True](function)


def as_binary[A: RegisterPassable & Deinitable, B: Movable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> NativeBinary[A, B, R, E, type_of(function), True] where not conforms_to(B, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The native error type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, E, type_of(function), True](function)


def as_binary[A: RegisterPassable & Deinitable, B: RegisterPassable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> NativeBinary[A, B, R, E, type_of(function), True] where not conforms_to(R, RegisterPassable):
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The native error type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, E, type_of(function), True](function)


def as_binary[A: RegisterPassable & Deinitable, B: RegisterPassable & Deinitable, R: RegisterPassable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin -> R
) -> NativeBinary[A, B, R, E, type_of(function), True]:
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        R: The result type.
        E: The native error type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, R, E, type_of(function), True](function)


def as_binary[A: Movable & Deinitable, B: Movable & Deinitable, E: Movable & Deinitable, //](
    function: def(var A, var B) raises E thin
) -> NativeBinary[A, B, type_of(None), E, type_of(function), True]:
    """Store a plain binary function or thin pointer as a reusable `Binary`.

    The adapter owns a copy of the pointer and construction never calls it.
    Use the adapter directly, or borrow it by name in supported binary
    iterator operations. Native closures with captures are not admitted by
    this factory. Most consumers already accept native callbacks directly.
    `fp.functions` re-exports this factory.

    Parameters:
        A: The first owned argument's type.
        B: The second owned argument's type.
        E: The native error type.


    Args:
        function: A plain function or stored thin pointer taking two arguments.

    Returns:
        A `NativeBinary` preserving the exact native signature and copyability.
    """
    return NativeBinary[A, B, type_of(None), E, type_of(function), True](function)


# --- end native binary admission ---


# Preserve the P: AnyType / R admission spelling when recovering native
# borrowing conformance, just as owned callbacks preserve A/R above.
comptime _Borrowing[P: AnyType, R: Movable & Deinitable] = def(P) -> R
comptime _RaisingBorrowing[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable] = def(P) raises E -> R



def _call_lazy_borrow[P: AnyType, R: Movable & Deinitable, F: Movable & Deinitable](
    mut function: F, ref value: P
) -> R:
    # Owned native captures need mutable invocation at O3. The eager bridge
    # borrows a callback in place; lazy iteration owns it between pulls.
    # Recover each literal signature from a value-bound F here. Retaining a
    # generic -> R constraint on F hides the no-value register signature.
    comptime if R == type_of(None):
        comptime if conforms_to(P, TrivialRegisterPassable):
            comptime Arg = downcast[P, TrivialRegisterPassable]
            comptime if conforms_to(F, def(Arg)):
                comptime Fn = downcast[F, def(Arg)]
                _ = rebind[Fn](function)(rebind_var[Arg](value))
                return rebind_var[R](None)
        comptime Fn = downcast[F, def(P)]
        _ = rebind[Fn](function)(value)
        return rebind_var[R](None)
    else:
        comptime Fn = downcast[F, _Borrowing[P, R]]
        return rebind[Fn](function)(value)


def _call_lazy_thunk[R: Movable & Deinitable, F: _Thunk[R]](mut function: F) -> R:
    return function()


@fieldwise_init
struct _NativeBorrowMut[P: AnyType, R: Movable & Deinitable, F: Movable & Deinitable, factory: Bool = False](
    _MutableBorrow, Copyable where conforms_to(F, Copyable)
):
    # Lazy pipelines own native captures and invoke them with mutable access.
    # The shared retention adapter still owns borrowing and payload disposal.
    var _function: _OptionalCell[Self.F]

    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)
    comptime Payload = Self.P
    comptime Result = Self.R
    comptime Failure = Never
    def invoke_mut(mut self, ref payload: Self.P) raises Self.Failure capturing -> Self.R:
        comptime if Self.factory:
            comptime Fn = downcast[Self.F, _Thunk[Self.R]]
            comptime assert conforms_to(Fn, _Thunk[Self.R])
            return _call_lazy_thunk[Self.R, Fn](rebind[Fn](self._function.value()))
        else:
            comptime Fn = downcast[Self.F, _Borrowing[Self.P, Self.R]]
            comptime assert conforms_to(Fn, _Borrowing[Self.P, Self.R])
            return _call_lazy_borrow[Self.P, Self.R, Fn](rebind[Fn](self._function.value()), payload)



@fieldwise_init
struct _NativeBorrow[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable,
                     F: Movable & Deinitable, raising: Bool](BorrowCallable, Copyable where conforms_to(F, Copyable)):
    # A native function or closure with a read parameter, as a BorrowCallable:
    # the payload stays borrowed for the call.
    comptime Payload = Self.P
    comptime Result = Self.R
    comptime Failure = Self.E
    var _function: _OptionalCell[Self.F]

    def __init__(out self, var function: Self.F):
        self._function = Optional(function^)

    def invoke(self, ref payload: Self.P) raises Self.E capturing -> Self.R:
        return _call_native_borrow[Self.P, Self.R, Self.E, Self.F, Self.raising](self._function.value(), payload)


def _call_native_borrow[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable,
                        F: Movable & Deinitable, raising: Bool](function: F, ref payload: P) raises E -> R:
    # --- native invocation: borrow (generated) ---
    comptime if R == type_of(None) and conforms_to(P, TrivialRegisterPassable):
        comptime Arg = downcast[P, TrivialRegisterPassable]
        comptime if raising and E == Never:
            comptime if F == def(Arg) raises Never thin or conforms_to(F, def(Arg) raises Never):
                _call_native_register_void[Arg, Never, F, True](function, rebind_var[Arg](payload))
                return rebind_var[R](None)
        elif raising:
            comptime if F == def(Arg) raises E thin or conforms_to(F, def(Arg) raises E):
                _call_native_register_void[Arg, E, F, True](function, rebind_var[Arg](payload))
                return rebind_var[R](None)
        else:
            comptime if F == def(Arg) thin or conforms_to(F, def(Arg)):
                _call_native_register_void[Arg, Never, F, False](function, rebind_var[Arg](payload))
                return rebind_var[R](None)
    comptime if conforms_to(P, TrivialRegisterPassable) and R == type_of(None):
        comptime Arg0 = downcast[P, TrivialRegisterPassable]
        comptime if raising and E == Never and F == def(Arg0) raises Never thin:
            _ = rebind[def(Arg0) raises Never thin](function)(rebind[Arg0](payload))
            return rebind_var[R](None)
        elif raising and F == def(Arg0) raises E thin:
            _ = rebind[def(Arg0) raises E thin](function)(rebind[Arg0](payload))
            return rebind_var[R](None)
        elif not raising and F == def(Arg0) thin:
            comptime assert E == Never
            _ = rebind[def(Arg0) thin](function)(rebind[Arg0](payload))
            return rebind_var[R](None)
    comptime if not conforms_to(P, TrivialRegisterPassable) and conforms_to(R, RegisterPassable):
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and E == Never and F == def(P) raises Never thin -> Out:
            return rebind_var[R](rebind[def(P) raises Never thin -> Out](function)(payload))
        elif raising and F == def(P) raises E thin -> Out:
            return rebind_var[R](rebind[def(P) raises E thin -> Out](function)(payload))
        elif not raising and F == def(P) thin -> Out:
            comptime assert E == Never
            return rebind_var[R](rebind[def(P) thin -> Out](function)(payload))
    comptime if conforms_to(P, TrivialRegisterPassable) and not conforms_to(R, RegisterPassable):
        comptime Arg0 = downcast[P, TrivialRegisterPassable]
        comptime if raising and E == Never and F == def(Arg0) raises Never thin -> R:
            return rebind_var[R](rebind[def(Arg0) raises Never thin -> R](function)(rebind[Arg0](payload)))
        elif raising and F == def(Arg0) raises E thin -> R:
            return rebind_var[R](rebind[def(Arg0) raises E thin -> R](function)(rebind[Arg0](payload)))
        elif not raising and F == def(Arg0) thin -> R:
            comptime assert E == Never
            return rebind_var[R](rebind[def(Arg0) thin -> R](function)(rebind[Arg0](payload)))
    comptime if conforms_to(P, TrivialRegisterPassable) and conforms_to(R, RegisterPassable):
        comptime Arg0 = downcast[P, TrivialRegisterPassable]
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and E == Never and F == def(Arg0) raises Never thin -> Out:
            return rebind_var[R](rebind[def(Arg0) raises Never thin -> Out](function)(rebind[Arg0](payload)))
        elif raising and F == def(Arg0) raises E thin -> Out:
            return rebind_var[R](rebind[def(Arg0) raises E thin -> Out](function)(rebind[Arg0](payload)))
        elif not raising and F == def(Arg0) thin -> Out:
            comptime assert E == Never
            return rebind_var[R](rebind[def(Arg0) thin -> Out](function)(rebind[Arg0](payload)))
    comptime if R == type_of(None) and raising and E == Never and F == def(P) raises Never thin:
        _ = rebind[def(P) raises Never thin](function)(payload)
        return rebind_var[R](None)
    comptime if R == type_of(None) and raising and F == def(P) raises E thin:
        _ = rebind[def(P) raises E thin](function)(payload)
        return rebind_var[R](None)
    comptime if R == type_of(None) and not raising and F == def(P) thin:
        comptime assert E == Never
        _ = rebind[def(P) thin](function)(payload)
        return rebind_var[R](None)
    comptime if raising and E == Never and F == def(P) raises Never thin -> R:
        return rebind[def(P) raises Never thin -> R](function)(payload)
    comptime if raising and F == def(P) raises E thin -> R:
        return rebind[def(P) raises E thin -> R](function)(payload)
    comptime if not raising and F == def(P) thin -> R:
        comptime assert E == Never
        return rebind[def(P) thin -> R](function)(payload)
    comptime if R == type_of(None) and raising and E == Never:
        comptime Fn = downcast[F, def(P) raises Never]
        _ = rebind[Fn](function)(payload)
        return rebind_var[R](None)
    elif R == type_of(None) and raising:
        comptime Fn = downcast[F, def(P) raises E]
        _ = rebind[Fn](function)(payload)
        return rebind_var[R](None)
    elif R == type_of(None) and not raising:
        comptime assert E == Never
        comptime Fn = downcast[F, def(P)]
        _ = rebind[Fn](function)(payload)
        return rebind_var[R](None)
    elif raising and E == Never:
        comptime Fn = downcast[F, def(P) raises Never -> R]
        return rebind[Fn](function)(payload)
    elif raising:
        comptime Fn = downcast[F, def(P) raises E -> R]
        return rebind[Fn](function)(payload)
    elif True:
        comptime assert E == Never
        comptime Fn = downcast[F, def(P) -> R]
        return rebind[Fn](function)(payload)
    # --- end native invocation ---


@fieldwise_init
struct _NativeBorrowRef[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable,
                        F: Movable & Deinitable, raising: Bool, o: ImmOrigin](BorrowCallable, ImplicitlyCopyable):
    """Borrow a native callback without copying its captures; invocation is shared."""
    comptime Payload = Self.P
    comptime Result = Self.R
    comptime Failure = Self.E
    var function: Pointer[Self.F, Self.o]
    def invoke(self, ref payload: Self.P) raises Self.E capturing -> Self.R:
        return _call_native_borrow[Self.P, Self.R, Self.E, Self.F, Self.raising](self.function[], payload)


# Fixed-arity pipelines admit symbolic function types through spelled thin
# signatures. These owners retain each arity's parameter ordering without a
# conversion to a closure trait; the stored value is a function pointer.
comptime _Thin0[R: Movable & Deinitable, E: Movable & Deinitable, Args: TypeList[Trait=Movable & Deinitable, ...]] = def() raises E thin -> R
comptime _Thin1[R: Movable & Deinitable, E: Movable & Deinitable, Args: TypeList[Trait=Movable & Deinitable, ...]] = def(var Args[0]) raises E thin -> R
comptime _Thin2[R: Movable & Deinitable, E: Movable & Deinitable, Args: TypeList[Trait=Movable & Deinitable, ...]] = def(var Args[0], var Args[1]) raises E thin -> R
comptime _Thin[R: Movable & Deinitable, E: Movable & Deinitable, Args: TypeList[Trait=Movable & Deinitable, ...]] = (
    _Thin0[R, E, Args] if Args.length == 0 else _Thin1[R, E, Args] if Args.length == 1 else _Thin2[R, E, Args]
)


@fieldwise_init
struct _ThinFunction[R: Movable & Deinitable, E: Movable & Deinitable,
                     Args: TypeList[Trait=Movable & Deinitable, ...]](
    ImplicitlyCopyable, Thunk where Args.length == 0, Unary where Args.length == 1, Binary where Args.length == 2
):
    comptime Arg = Self.Args[0]
    comptime First = Self.Args[0]
    comptime Second = Self.Args[1]
    comptime Out = Self.R
    comptime Error = Self.E
    var function: _Thin[Self.R, Self.E, Self.Args]

    def call(self) raises Self.E -> Self.R:
        return rebind[_Thin0[Self.R, Self.E, Self.Args]](self.function)()

    def call(self, var arg: Self.Arg) raises Self.E -> Self.R:
        return rebind[_Thin1[Self.R, Self.E, Self.Args]](self.function)(arg^)

    def call(self, var first: Self.First, var second: Self.Second) raises Self.E -> Self.R:
        return rebind[_Thin2[Self.R, Self.E, Self.Args]](self.function)(first^, second^)


comptime _Thin0F[R: Movable & Deinitable, E: Movable & Deinitable] = _ThinFunction[R, E, TypeList.of[Trait=Movable & Deinitable]()]
comptime _Thin1F[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable] = _ThinFunction[R, E, TypeList.of[Trait=Movable & Deinitable, A]()]
comptime _Thin2F[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable] = _ThinFunction[R, E, TypeList.of[Trait=Movable & Deinitable, A, B]()]


def _call_native_keywords[K: Movable & Deinitable, R: Movable & Deinitable,
                          E: Movable & Deinitable, F: Movable & Deinitable,
                          raising: Bool](function: F, /, var **values: K) raises E -> R:
    # --- native invocation: keywords (generated) ---
    comptime if conforms_to(R, RegisterPassable):
        comptime Out = downcast[R, RegisterPassable & Deinitable]
        comptime if raising and E == Never and F == def(var **kwargs: K) raises Never thin -> Out:
            return rebind_var[R](rebind[def(var **kwargs: K) raises Never thin -> Out](function)(**values^))
        elif raising and F == def(var **kwargs: K) raises E thin -> Out:
            return rebind_var[R](rebind[def(var **kwargs: K) raises E thin -> Out](function)(**values^))
        elif not raising and F == def(var **kwargs: K) thin -> Out:
            comptime assert E == Never
            return rebind_var[R](rebind[def(var **kwargs: K) thin -> Out](function)(**values^))
    comptime if R == type_of(None) and raising and E == Never and F == def(var **kwargs: K) raises Never thin:
        _ = rebind[def(var **kwargs: K) raises Never thin](function)(**values^)
        return rebind_var[R](None)
    comptime if R == type_of(None) and raising and F == def(var **kwargs: K) raises E thin:
        _ = rebind[def(var **kwargs: K) raises E thin](function)(**values^)
        return rebind_var[R](None)
    comptime if R == type_of(None) and not raising and F == def(var **kwargs: K) thin:
        comptime assert E == Never
        _ = rebind[def(var **kwargs: K) thin](function)(**values^)
        return rebind_var[R](None)
    comptime if raising and E == Never and F == def(var **kwargs: K) raises Never thin -> R:
        return rebind[def(var **kwargs: K) raises Never thin -> R](function)(**values^)
    comptime if raising and F == def(var **kwargs: K) raises E thin -> R:
        return rebind[def(var **kwargs: K) raises E thin -> R](function)(**values^)
    comptime if not raising and F == def(var **kwargs: K) thin -> R:
        comptime assert E == Never
        return rebind[def(var **kwargs: K) thin -> R](function)(**values^)
    comptime if R == type_of(None) and raising and E == Never:
        comptime Fn = downcast[F, def(var **kwargs: K) raises Never]
        _ = rebind[Fn](function)(**values^)
        return rebind_var[R](None)
    elif R == type_of(None) and raising:
        comptime Fn = downcast[F, def(var **kwargs: K) raises E]
        _ = rebind[Fn](function)(**values^)
        return rebind_var[R](None)
    elif R == type_of(None) and not raising:
        comptime assert E == Never
        comptime Fn = downcast[F, def(var **kwargs: K)]
        _ = rebind[Fn](function)(**values^)
        return rebind_var[R](None)
    elif raising and E == Never:
        comptime Fn = downcast[F, def(var **kwargs: K) raises Never -> R]
        return rebind[Fn](function)(**values^)
    elif raising:
        comptime Fn = downcast[F, def(var **kwargs: K) raises E -> R]
        return rebind[Fn](function)(**values^)
    elif True:
        comptime assert E == Never
        comptime Fn = downcast[F, def(var **kwargs: K) -> R]
        return rebind[Fn](function)(**values^)
    # --- end native invocation ---


# Borrowed native views for convention-specific admission. Deliberately omit
# __call__: competing native def traits must reject these nominal values before
# Mojo 1.2 attempts effect inference for an incompatible argument convention.
# Each view keeps the exact F and origin; only its native signature differs.
# Literal no-value and raises Never spellings preserve the native witnesses.
@fieldwise_init
struct _NativeMutatingRef[A: Movable & Deinitable, R: Movable & Deinitable,
                        E: Movable & Deinitable, F: Movable & Deinitable,
                        raising: Bool, o: ImmOrigin](ImplicitlyCopyable):
    var function: Pointer[Self.F, Self.o]

    def invoke(self, mut value: Self.A) raises Self.E -> Self.R:
        # --- native invocation: mutating (generated) ---
        comptime if conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A) raises Never thin -> Out](self.function[])(value))
            elif Self.raising and Self.F == def(mut Self.A) raises Self.E thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A) raises Self.E thin -> Out](self.function[])(value))
            elif not Self.raising and Self.F == def(mut Self.A) thin -> Out:
                comptime assert Self.E == Never
                return rebind_var[Self.R](rebind[def(mut Self.A) thin -> Out](self.function[])(value))
        comptime if Self.R == type_of(None) and Self.raising and Self.E == Never and Self.F == def(mut Self.A) raises Never thin:
            _ = rebind[def(mut Self.A) raises Never thin](self.function[])(value)
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(mut Self.A) raises Self.E thin:
            _ = rebind[def(mut Self.A) raises Self.E thin](self.function[])(value)
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(mut Self.A) thin:
            comptime assert Self.E == Never
            _ = rebind[def(mut Self.A) thin](self.function[])(value)
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A) raises Never thin -> Self.R:
            return rebind[def(mut Self.A) raises Never thin -> Self.R](self.function[])(value)
        comptime if Self.raising and Self.F == def(mut Self.A) raises Self.E thin -> Self.R:
            return rebind[def(mut Self.A) raises Self.E thin -> Self.R](self.function[])(value)
        comptime if not Self.raising and Self.F == def(mut Self.A) thin -> Self.R:
            comptime assert Self.E == Never
            return rebind[def(mut Self.A) thin -> Self.R](self.function[])(value)
        comptime if Self.R == type_of(None) and Self.raising and Self.E == Never:
            comptime Fn = downcast[Self.F, def(mut Self.A) raises Never]
            _ = rebind[Fn](self.function[])(value)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(mut Self.A) raises Self.E]
            _ = rebind[Fn](self.function[])(value)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.E == Never
            comptime Fn = downcast[Self.F, def(mut Self.A)]
            _ = rebind[Fn](self.function[])(value)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.E == Never:
            comptime Fn = downcast[Self.F, def(mut Self.A) raises Never -> Self.R]
            return rebind[Fn](self.function[])(value)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(mut Self.A) raises Self.E -> Self.R]
            return rebind[Fn](self.function[])(value)
        elif True:
            comptime assert Self.E == Never
            comptime Fn = downcast[Self.F, def(mut Self.A) -> Self.R]
            return rebind[Fn](self.function[])(value)
        # --- end native invocation ---


@fieldwise_init
struct _NativeMutOwnedRef[A: Movable & Deinitable, B: Movable & Deinitable,
                        R: Movable & Deinitable, E: Movable & Deinitable,
                        F: Movable & Deinitable, raising: Bool, o: ImmOrigin](ImplicitlyCopyable):
    var function: Pointer[Self.F, Self.o]
    def invoke(self, mut first: Self.A, var second: Self.B) raises Self.E -> Self.R:
        # --- native invocation: mut_owned (generated) ---
        comptime if conforms_to(Self.B, RegisterPassable & Deinitable) and Self.R == type_of(None):
            comptime Arg1 = downcast[Self.B, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Arg1) raises Never thin:
                _ = rebind[def(mut Self.A, var Arg1) raises Never thin](self.function[])(first, rebind_var[Arg1](second^))
                return rebind_var[Self.R](None)
            elif Self.raising and Self.F == def(mut Self.A, var Arg1) raises Self.E thin:
                _ = rebind[def(mut Self.A, var Arg1) raises Self.E thin](self.function[])(first, rebind_var[Arg1](second^))
                return rebind_var[Self.R](None)
            elif not Self.raising and Self.F == def(mut Self.A, var Arg1) thin:
                comptime assert Self.E == Never
                _ = rebind[def(mut Self.A, var Arg1) thin](self.function[])(first, rebind_var[Arg1](second^))
                return rebind_var[Self.R](None)
        comptime if not conforms_to(Self.B, RegisterPassable & Deinitable) and conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Self.B) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Self.B) raises Never thin -> Out](self.function[])(first, second^))
            elif Self.raising and Self.F == def(mut Self.A, var Self.B) raises Self.E thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Self.B) raises Self.E thin -> Out](self.function[])(first, second^))
            elif not Self.raising and Self.F == def(mut Self.A, var Self.B) thin -> Out:
                comptime assert Self.E == Never
                return rebind_var[Self.R](rebind[def(mut Self.A, var Self.B) thin -> Out](self.function[])(first, second^))
        comptime if conforms_to(Self.B, RegisterPassable & Deinitable) and not conforms_to(Self.R, RegisterPassable):
            comptime Arg1 = downcast[Self.B, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Arg1) raises Never thin -> Self.R:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1) raises Never thin -> Self.R](self.function[])(first, rebind_var[Arg1](second^)))
            elif Self.raising and Self.F == def(mut Self.A, var Arg1) raises Self.E thin -> Self.R:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1) raises Self.E thin -> Self.R](self.function[])(first, rebind_var[Arg1](second^)))
            elif not Self.raising and Self.F == def(mut Self.A, var Arg1) thin -> Self.R:
                comptime assert Self.E == Never
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1) thin -> Self.R](self.function[])(first, rebind_var[Arg1](second^)))
        comptime if conforms_to(Self.B, RegisterPassable & Deinitable) and conforms_to(Self.R, RegisterPassable):
            comptime Arg1 = downcast[Self.B, RegisterPassable & Deinitable]
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Arg1) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1) raises Never thin -> Out](self.function[])(first, rebind_var[Arg1](second^)))
            elif Self.raising and Self.F == def(mut Self.A, var Arg1) raises Self.E thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1) raises Self.E thin -> Out](self.function[])(first, rebind_var[Arg1](second^)))
            elif not Self.raising and Self.F == def(mut Self.A, var Arg1) thin -> Out:
                comptime assert Self.E == Never
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1) thin -> Out](self.function[])(first, rebind_var[Arg1](second^)))
        comptime if Self.R == type_of(None) and Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Self.B) raises Never thin:
            _ = rebind[def(mut Self.A, var Self.B) raises Never thin](self.function[])(first, second^)
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(mut Self.A, var Self.B) raises Self.E thin:
            _ = rebind[def(mut Self.A, var Self.B) raises Self.E thin](self.function[])(first, second^)
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(mut Self.A, var Self.B) thin:
            comptime assert Self.E == Never
            _ = rebind[def(mut Self.A, var Self.B) thin](self.function[])(first, second^)
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Self.B) raises Never thin -> Self.R:
            return rebind[def(mut Self.A, var Self.B) raises Never thin -> Self.R](self.function[])(first, second^)
        comptime if Self.raising and Self.F == def(mut Self.A, var Self.B) raises Self.E thin -> Self.R:
            return rebind[def(mut Self.A, var Self.B) raises Self.E thin -> Self.R](self.function[])(first, second^)
        comptime if not Self.raising and Self.F == def(mut Self.A, var Self.B) thin -> Self.R:
            comptime assert Self.E == Never
            return rebind[def(mut Self.A, var Self.B) thin -> Self.R](self.function[])(first, second^)
        comptime if Self.R == type_of(None) and Self.raising and Self.E == Never:
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B) raises Never]
            _ = rebind[Fn](self.function[])(first, second^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B) raises Self.E]
            _ = rebind[Fn](self.function[])(first, second^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.E == Never
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B)]
            _ = rebind[Fn](self.function[])(first, second^)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.E == Never:
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B) raises Never -> Self.R]
            return rebind[Fn](self.function[])(first, second^)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B) raises Self.E -> Self.R]
            return rebind[Fn](self.function[])(first, second^)
        elif True:
            comptime assert Self.E == Never
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B) -> Self.R]
            return rebind[Fn](self.function[])(first, second^)
        # --- end native invocation ---


@fieldwise_init
struct _NativeMutOwnedKeywordsRef[A: Movable & Deinitable, B: Movable & Deinitable, K: Movable & Deinitable,
                          R: Movable & Deinitable, E: Movable & Deinitable,
                          F: Movable & Deinitable, raising: Bool, o: ImmOrigin](ImplicitlyCopyable):
    var function: Pointer[Self.F, Self.o]
    def invoke(self, mut first: Self.A, var second: Self.B, /, var **values: Self.K) raises Self.E -> Self.R:
        # --- native invocation: mut_owned_keywords (generated) ---
        comptime if conforms_to(Self.B, RegisterPassable & Deinitable) and Self.R == type_of(None):
            comptime Arg1 = downcast[Self.B, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Never thin:
                _ = rebind[def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Never thin](self.function[])(first, rebind_var[Arg1](second^), **values^)
                return rebind_var[Self.R](None)
            elif Self.raising and Self.F == def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Self.E thin:
                _ = rebind[def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Self.E thin](self.function[])(first, rebind_var[Arg1](second^), **values^)
                return rebind_var[Self.R](None)
            elif not Self.raising and Self.F == def(mut Self.A, var Arg1, /, var **kwargs: Self.K) thin:
                comptime assert Self.E == Never
                _ = rebind[def(mut Self.A, var Arg1, /, var **kwargs: Self.K) thin](self.function[])(first, rebind_var[Arg1](second^), **values^)
                return rebind_var[Self.R](None)
        comptime if not conforms_to(Self.B, RegisterPassable & Deinitable) and conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin -> Out](self.function[])(first, second^, **values^))
            elif Self.raising and Self.F == def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E thin -> Out](self.function[])(first, second^, **values^))
            elif not Self.raising and Self.F == def(mut Self.A, var Self.B, /, var **kwargs: Self.K) thin -> Out:
                comptime assert Self.E == Never
                return rebind_var[Self.R](rebind[def(mut Self.A, var Self.B, /, var **kwargs: Self.K) thin -> Out](self.function[])(first, second^, **values^))
        comptime if conforms_to(Self.B, RegisterPassable & Deinitable) and not conforms_to(Self.R, RegisterPassable):
            comptime Arg1 = downcast[Self.B, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Never thin -> Self.R:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Never thin -> Self.R](self.function[])(first, rebind_var[Arg1](second^), **values^))
            elif Self.raising and Self.F == def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Self.E thin -> Self.R:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Self.E thin -> Self.R](self.function[])(first, rebind_var[Arg1](second^), **values^))
            elif not Self.raising and Self.F == def(mut Self.A, var Arg1, /, var **kwargs: Self.K) thin -> Self.R:
                comptime assert Self.E == Never
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1, /, var **kwargs: Self.K) thin -> Self.R](self.function[])(first, rebind_var[Arg1](second^), **values^))
        comptime if conforms_to(Self.B, RegisterPassable & Deinitable) and conforms_to(Self.R, RegisterPassable):
            comptime Arg1 = downcast[Self.B, RegisterPassable & Deinitable]
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Never thin -> Out](self.function[])(first, rebind_var[Arg1](second^), **values^))
            elif Self.raising and Self.F == def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Self.E thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1, /, var **kwargs: Self.K) raises Self.E thin -> Out](self.function[])(first, rebind_var[Arg1](second^), **values^))
            elif not Self.raising and Self.F == def(mut Self.A, var Arg1, /, var **kwargs: Self.K) thin -> Out:
                comptime assert Self.E == Never
                return rebind_var[Self.R](rebind[def(mut Self.A, var Arg1, /, var **kwargs: Self.K) thin -> Out](self.function[])(first, rebind_var[Arg1](second^), **values^))
        comptime if Self.R == type_of(None) and Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin:
            _ = rebind[def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin](self.function[])(first, second^, **values^)
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E thin:
            _ = rebind[def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E thin](self.function[])(first, second^, **values^)
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(mut Self.A, var Self.B, /, var **kwargs: Self.K) thin:
            comptime assert Self.E == Never
            _ = rebind[def(mut Self.A, var Self.B, /, var **kwargs: Self.K) thin](self.function[])(first, second^, **values^)
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin -> Self.R:
            return rebind[def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never thin -> Self.R](self.function[])(first, second^, **values^)
        comptime if Self.raising and Self.F == def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E thin -> Self.R:
            return rebind[def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E thin -> Self.R](self.function[])(first, second^, **values^)
        comptime if not Self.raising and Self.F == def(mut Self.A, var Self.B, /, var **kwargs: Self.K) thin -> Self.R:
            comptime assert Self.E == Never
            return rebind[def(mut Self.A, var Self.B, /, var **kwargs: Self.K) thin -> Self.R](self.function[])(first, second^, **values^)
        comptime if Self.R == type_of(None) and Self.raising and Self.E == Never:
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never]
            _ = rebind[Fn](self.function[])(first, second^, **values^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E]
            _ = rebind[Fn](self.function[])(first, second^, **values^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.E == Never
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B, /, var **kwargs: Self.K)]
            _ = rebind[Fn](self.function[])(first, second^, **values^)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.E == Never:
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Never -> Self.R]
            return rebind[Fn](self.function[])(first, second^, **values^)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B, /, var **kwargs: Self.K) raises Self.E -> Self.R]
            return rebind[Fn](self.function[])(first, second^, **values^)
        elif True:
            comptime assert Self.E == Never
            comptime Fn = downcast[Self.F, def(mut Self.A, var Self.B, /, var **kwargs: Self.K) -> Self.R]
            return rebind[Fn](self.function[])(first, second^, **values^)
        # --- end native invocation ---


# A mutable prefix plus an owned keyword pack needs a literal native signature.
# Keep no-value and explicit Never witnesses here, alongside other native views;
# attempt_kwargs delegates invocation without changing argument ownership.
@fieldwise_init
struct _NativeMutatingKeywordsRef[A: Movable & Deinitable, K: Movable & Deinitable,
                          R: Movable & Deinitable, E: Movable & Deinitable,
                          F: Movable & Deinitable, raising: Bool, o: ImmOrigin](ImplicitlyCopyable):
    var function: Pointer[Self.F, Self.o]
    def invoke(self, mut first: Self.A, /, var **values: Self.K) raises Self.E -> Self.R:
        # --- native invocation: mutating_keywords (generated) ---
        comptime if conforms_to(Self.R, RegisterPassable):
            comptime Out = downcast[Self.R, RegisterPassable & Deinitable]
            comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, /, var **kwargs: Self.K) raises Never thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, /, var **kwargs: Self.K) raises Never thin -> Out](self.function[])(first, **values^))
            elif Self.raising and Self.F == def(mut Self.A, /, var **kwargs: Self.K) raises Self.E thin -> Out:
                return rebind_var[Self.R](rebind[def(mut Self.A, /, var **kwargs: Self.K) raises Self.E thin -> Out](self.function[])(first, **values^))
            elif not Self.raising and Self.F == def(mut Self.A, /, var **kwargs: Self.K) thin -> Out:
                comptime assert Self.E == Never
                return rebind_var[Self.R](rebind[def(mut Self.A, /, var **kwargs: Self.K) thin -> Out](self.function[])(first, **values^))
        comptime if Self.R == type_of(None) and Self.raising and Self.E == Never and Self.F == def(mut Self.A, /, var **kwargs: Self.K) raises Never thin:
            _ = rebind[def(mut Self.A, /, var **kwargs: Self.K) raises Never thin](self.function[])(first, **values^)
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and Self.raising and Self.F == def(mut Self.A, /, var **kwargs: Self.K) raises Self.E thin:
            _ = rebind[def(mut Self.A, /, var **kwargs: Self.K) raises Self.E thin](self.function[])(first, **values^)
            return rebind_var[Self.R](None)
        comptime if Self.R == type_of(None) and not Self.raising and Self.F == def(mut Self.A, /, var **kwargs: Self.K) thin:
            comptime assert Self.E == Never
            _ = rebind[def(mut Self.A, /, var **kwargs: Self.K) thin](self.function[])(first, **values^)
            return rebind_var[Self.R](None)
        comptime if Self.raising and Self.E == Never and Self.F == def(mut Self.A, /, var **kwargs: Self.K) raises Never thin -> Self.R:
            return rebind[def(mut Self.A, /, var **kwargs: Self.K) raises Never thin -> Self.R](self.function[])(first, **values^)
        comptime if Self.raising and Self.F == def(mut Self.A, /, var **kwargs: Self.K) raises Self.E thin -> Self.R:
            return rebind[def(mut Self.A, /, var **kwargs: Self.K) raises Self.E thin -> Self.R](self.function[])(first, **values^)
        comptime if not Self.raising and Self.F == def(mut Self.A, /, var **kwargs: Self.K) thin -> Self.R:
            comptime assert Self.E == Never
            return rebind[def(mut Self.A, /, var **kwargs: Self.K) thin -> Self.R](self.function[])(first, **values^)
        comptime if Self.R == type_of(None) and Self.raising and Self.E == Never:
            comptime Fn = downcast[Self.F, def(mut Self.A, /, var **kwargs: Self.K) raises Never]
            _ = rebind[Fn](self.function[])(first, **values^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and Self.raising:
            comptime Fn = downcast[Self.F, def(mut Self.A, /, var **kwargs: Self.K) raises Self.E]
            _ = rebind[Fn](self.function[])(first, **values^)
            return rebind_var[Self.R](None)
        elif Self.R == type_of(None) and not Self.raising:
            comptime assert Self.E == Never
            comptime Fn = downcast[Self.F, def(mut Self.A, /, var **kwargs: Self.K)]
            _ = rebind[Fn](self.function[])(first, **values^)
            return rebind_var[Self.R](None)
        elif Self.raising and Self.E == Never:
            comptime Fn = downcast[Self.F, def(mut Self.A, /, var **kwargs: Self.K) raises Never -> Self.R]
            return rebind[Fn](self.function[])(first, **values^)
        elif Self.raising:
            comptime Fn = downcast[Self.F, def(mut Self.A, /, var **kwargs: Self.K) raises Self.E -> Self.R]
            return rebind[Fn](self.function[])(first, **values^)
        elif True:
            comptime assert Self.E == Never
            comptime Fn = downcast[Self.F, def(mut Self.A, /, var **kwargs: Self.K) -> Self.R]
            return rebind[Fn](self.function[])(first, **values^)
        # --- end native invocation ---
