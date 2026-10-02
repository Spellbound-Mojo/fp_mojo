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


comptime _Unary[A: Movable & Deinitable, R: Movable & Deinitable] = def(var A) -> R


comptime _RaisingUnary[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable] = def(var A) raises E -> R


def _native_unary[A: Movable & Deinitable, R: Movable & Deinitable,
                F: _Unary[A, R]](function: F, var value: A) -> R:
    return function(value^)


def _native_raising_unary[A: Movable & Deinitable, R: Movable & Deinitable,
                        E: Movable & Deinitable, F: _RaisingUnary[A, R, E]](
    function: F, var value: A
) raises E -> R:
    return function(value^)


# Factory parameter names are part of native conformance recovery on Mojo 1.1.
# Iterator factories introduce T/U (including an Optional result), while pipeline
# promotion introduces A/R. Keep those admission spellings; invocation is shared.
comptime _LazyUnary[T: Movable & Deinitable, U: Movable & Deinitable] = def(var T) -> U
comptime _LazyOptional[T: Movable & Deinitable, U: Movable & Deinitable] = def(var T) -> Optional[U]


def _call_native[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                 F: Movable & Deinitable, raising: Bool](function: F, var value: A) raises E -> R:
    # The one native-def call for owned unary callbacks: NativeUnary, the
    # borrowed reference view and pipeline stages all reach it.
    comptime if raising:
        comptime Fn = downcast[F, _RaisingUnary[A, R, E]]
        comptime assert Fn.A == A and Fn.R == R and Fn.E == E, "native unary: incompatible signature"
        return _native_raising_unary[A, R, E, Fn](rebind[Fn](function), value^)
    else:
        comptime assert E == Never
        comptime Fn = downcast[F, _Unary[A, R]]
        comptime assert Fn.A == A and Fn.R == R, "native unary: incompatible signature"
        return _native_unary[A, R, Fn](rebind[Fn](function), value^)


@fieldwise_init
struct NativeUnary[A: Movable & Deinitable, R: Movable & Deinitable,
                   E: Movable & Deinitable, F: Movable & Deinitable,
                   raising: Bool](Unary, Copyable where conforms_to(F, Copyable),
                                  ImplicitlyCopyable where conforms_to(F, ImplicitlyCopyable)):
    """A native function or closure stored as a `Unary` value, made by `as_unary`.

    It is `Copyable` when the stored function is. At O3 a call through it
    compiles to the same instructions as a direct call.

    Parameters:
        A: The argument type.
        R: The result type.
        E: The error type; `Never` for a function that does not raise.
        F: The stored function's type.
        raising: Whether the stored function raises.
    """
    var function: Self.F
    """The stored function or closure."""
    comptime Arg = Self.A
    comptime Out = Self.R
    comptime Error = Self.E
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        """Call the stored function.

        Args:
            arg: The argument, consumed.

        Returns:
            The function's result.

        Raises:
            The function's error, unchanged; nothing when it does not raise.
        """
        return _call_native[Self.A, Self.R, Self.E, Self.F, Self.raising](self.function, arg^)

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
    take native functions without it; it is needed for closures in pipelines
    and compositions, and wherever generic code needs a `Unary` value.
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


comptime _Borrowing[P: AnyType, R: Movable & Deinitable] = def(P) -> R
comptime _RaisingBorrowing[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable] = def(P) raises E -> R



def _native_borrow[P: AnyType, R: Movable & Deinitable, F: _Borrowing[P, R]](function: F, ref payload: P) -> R:
    return function(payload)


def _native_raising_borrow[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable,
                           F: _RaisingBorrowing[P, R, E]](function: F, ref payload: P) raises E -> R:
    return function(payload)


@fieldwise_init
struct _NativeBorrow[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable,
                     F: Movable & Deinitable, raising: Bool](BorrowCallable, Copyable where conforms_to(F, Copyable)):
    # A native function or closure with a read parameter, as a BorrowCallable:
    # the payload stays borrowed for the call.
    comptime Payload = Self.P
    comptime Result = Self.R
    comptime Failure = Self.E
    var function: Self.F

    def invoke(self, ref payload: Self.P) raises Self.E capturing -> Self.R:
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingBorrowing[Self.P, Self.R, Self.E]]
            comptime assert Fn.P == Self.P and Fn.R == Self.R and Fn.E == Self.E, "native borrow: incompatible signature"
            return _native_raising_borrow[Self.P, Self.R, Self.E, Fn](rebind[Fn](self.function), payload)
        else:
            comptime assert Self.E == Never
            comptime Fn = downcast[Self.F, _Borrowing[Self.P, Self.R]]
            comptime assert Fn.P == Self.P and Fn.R == Self.R, "native borrow: incompatible signature"
            return _native_borrow[Self.P, Self.R, Fn](rebind[Fn](self.function), payload)


# A plain function whose parameter, result or error types are still symbolic at
# the call site converts only to a spelled thin signature, never to a closure
# trait such as _Unary, so NativeUnary cannot hold it. Each arity keeps its own
# thin signature; the stored value is a function pointer.
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
