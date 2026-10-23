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
from ._receiver import _MutableBorrow


comptime _Thunk[R: Movable & Deinitable] = def() -> R
comptime _RaisingThunk[R: Movable & Deinitable, E: Movable & Deinitable] = def() raises E -> R


def _native_thunk[R: Movable & Deinitable, F: _Thunk[R]](function: F) -> R:
    return function()


def _native_raising_thunk[R: Movable & Deinitable, X: Movable & Deinitable, F: _RaisingThunk[R, X]](function: F) raises X -> R:
    return function()


@fieldwise_init
struct _NativeThunkRef[R: Movable & Deinitable, X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Thunk, ImplicitlyCopyable):
    # R/X is the general factory boundary; conditional branches retain their
    # distinct U/Y and W/D native signature spellings below on Mojo 1.1.
    var function: Pointer[Self.F, Self.o]
    comptime Out = Self.R
    comptime Error = Self.X
    def call(self) raises Self.Error -> Self.Out:
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingThunk[Self.R, Self.X]]
            comptime assert Fn.R == Self.R and Fn.X == Self.X
            return _native_raising_thunk[Self.R, Self.X, Fn](rebind[Fn](self.function[]))
        else:
            comptime assert Self.X == Never
            comptime Fn = downcast[Self.F, _Thunk[Self.R]]
            comptime assert Fn.R == Self.R
            return _native_thunk[Self.R, Fn](rebind[Fn](self.function[]))


# Mojo 1.1's native function witnesses retain the generic result/error names.
# Conditional syntax admits U/Y on the left and W/D on the right. Keep these
# two native signatures here; receiver dispatch and branch selection are shared.
@fieldwise_init
struct _NativeBranchLeft[U: Movable & Deinitable, Y: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Thunk, ImplicitlyCopyable):
    var function: Pointer[Self.F, Self.o]
    comptime Out = Self.U
    comptime Error = Self.Y
    def call(self) raises Self.Y -> Self.U:
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingThunk[Self.U, Self.Y]]
            return rebind[Fn](self.function[])[_U=Self.U, _Y=Self.Y]()
        else:
            comptime assert Self.Y == Never
            comptime Fn = downcast[Self.F, _Thunk[Self.U]]
            return rebind[Fn](self.function[])[_U=Self.U]()


@fieldwise_init
struct _NativeBranchRight[W: Movable & Deinitable, D: Movable & Deinitable, F: Movable & Deinitable, raising: Bool, o: ImmOrigin](Thunk, ImplicitlyCopyable):
    var function: Pointer[Self.F, Self.o]
    comptime Out = Self.W
    comptime Error = Self.D
    def call(self) raises Self.D -> Self.W:
        comptime if Self.raising:
            comptime Fn = downcast[Self.F, _RaisingThunk[Self.W, Self.D]]
            return rebind[Fn](self.function[])[_W=Self.W, _D=Self.D]()
        else:
            comptime assert Self.D == Never
            comptime Fn = downcast[Self.F, _Thunk[Self.W]]
            return rebind[Fn](self.function[])[_W=Self.W]()


comptime _Binary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable] = def(var A, var B) -> R
comptime _RaisingBinary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable] = def(var A, var B) raises X -> R


def _native_binary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                   F: _Binary[A, B, R]](function: F, var first: A, var second: B) -> R:
    return function(first^, second^)


def _native_binary_raising[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                           X: Movable & Deinitable, F: _RaisingBinary[A, B, R, X]](
    function: F, var first: A, var second: B
) raises X -> R:
    return function(first^, second^)


def _call_native_binary[A: Movable & Deinitable, B: Movable & Deinitable, R: Movable & Deinitable,
                        X: Movable & Deinitable, F: Movable & Deinitable, raising: Bool](
    function: F, var first: A, var second: B
) raises X -> R:
    comptime if raising:
        comptime Fn = downcast[F, _RaisingBinary[A, B, R, X]]
        comptime assert Fn.A == A and Fn.B == B and Fn.R == R and Fn.X == X
        return _native_binary_raising[A, B, R, X, Fn](rebind[Fn](function), first^, second^)
    else:
        comptime assert X == Never
        comptime Fn = downcast[F, _Binary[A, B, R]]
        comptime assert Fn.A == A and Fn.B == B and Fn.R == R
        return _native_binary[A, B, R, Fn](rebind[Fn](function), first^, second^)


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
                       raising: Bool, origin: ImmOrigin, admitted: Bool = False,
                       apply: def(F, var A) raises E thin -> R = _unary_ref_call[A, R, E, F, raising]](Unary, ImplicitlyCopyable):
    # A borrowed native def. Generic forwarding holds a native function by
    # reference and cannot copy it; the call is the same as NativeUnary's.
    var function: Pointer[Self.F, Self.origin]
    comptime Arg = Self.A
    comptime Out = Self.R
    comptime Error = Self.E
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime if Self.admitted:
            return Self.apply(self.function[], arg^)
        else:
            return _call_native[Self.A, Self.R, Self.E, Self.F, Self.raising](self.function[], arg^)


def _unary_ref_call[A: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                    F: Movable & Deinitable, raising: Bool](function: F, var value: A) raises E -> R:
    return _call_native[A, R, E, F, raising](function, value^)


# Two native callbacks carry different witnesses on Mojo 1.1. These shims
# preserve their admitted parameter names; the reference view owns storage
# and receiver dispatch, and the family owns execution and error semantics.
def _unary_ref_left[A: Movable & Deinitable, R: Movable & Deinitable, X: Movable & Deinitable,
                    F: Movable & Deinitable, raising: Bool](function: F, var value: A) raises X -> R:
    comptime if raising:
        comptime Fn = downcast[F, _RaisingUnary[A, R, X]]
        return rebind[Fn](function)[_A=A, _R=R, _X=X](value^)
    else:
        comptime assert X == Never
        comptime Fn = downcast[F, _Unary[A, R]]
        return rebind[Fn](function)[_A=A, _R=R](value^)


def _unary_ref_right[Q: Movable & Deinitable, S: Movable & Deinitable, Y: Movable & Deinitable,
                     F: Movable & Deinitable, raising: Bool](function: F, var value: Q) raises Y -> S:
    comptime if raising:
        comptime Fn = downcast[F, _RaisingUnary[Q, S, Y]]
        return rebind[Fn](function)[_Q=Q, _S=S, _Y=Y](value^)
    else:
        comptime assert Y == Never
        comptime Fn = downcast[F, _Unary[Q, S]]
        return rebind[Fn](function)[_Q=Q, _S=S](value^)


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


# Preserve the P: AnyType / R admission spelling when recovering native
# borrowing conformance, just as owned callbacks preserve A/R above.
comptime _Borrowing[P: AnyType, R: Movable & Deinitable] = def(P) -> R
comptime _RaisingBorrowing[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable] = def(P) raises E -> R


def _native_borrow[P: AnyType, R: Movable & Deinitable, F: _Borrowing[P, R]](function: F, ref payload: P) -> R:
    return function(payload)


def _call_lazy_borrow[P: AnyType, R: Movable & Deinitable, F: _Borrowing[P, R]](
    mut function: F, ref value: P
) -> R:
    # Owned native captures need mutable invocation at O3. The eager bridge
    # borrows a callback in place; lazy iteration owns it between pulls.
    return function(value)


def _call_lazy_thunk[R: Movable & Deinitable, F: _Thunk[R]](mut function: F) -> R:
    return function()


@fieldwise_init
struct _NativeBorrowMut[P: AnyType, R: Movable & Deinitable, F: Movable & Deinitable, factory: Bool = False](
    _MutableBorrow, Copyable where conforms_to(F, Copyable)
):
    # Lazy pipelines own native captures and invoke them with mutable access.
    # The shared retention adapter still owns borrowing and payload disposal.
    var function: Self.F
    comptime Payload = Self.P
    comptime Result = Self.R
    comptime Failure = Never
    def invoke_mut(mut self, ref payload: Self.P) raises Self.Failure capturing -> Self.R:
        comptime if Self.factory:
            comptime Fn = downcast[Self.F, _Thunk[Self.R]]
            comptime assert Fn.R == Self.R
            return _call_lazy_thunk[Self.R, Fn](rebind[Fn](self.function))
        else:
            comptime Fn = downcast[Self.F, _Borrowing[Self.P, Self.R]]
            comptime assert Fn.P == Self.P and Fn.R == Self.R
            return _call_lazy_borrow[Self.P, Self.R, Fn](rebind[Fn](self.function), payload)


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
        return _call_native_borrow[Self.P, Self.R, Self.E, Self.F, Self.raising](self.function, payload)


def _call_native_borrow[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable,
                        F: Movable & Deinitable, raising: Bool](function: F, ref payload: P) raises E -> R:
    comptime if raising:
        comptime Fn = downcast[F, _RaisingBorrowing[P, R, E]]
        comptime assert Fn.P == P and Fn.R == R and Fn.E == E, "native borrow: incompatible signature"
        return _native_raising_borrow[P, R, E, Fn](rebind[Fn](function), payload)
    else:
        comptime assert E == Never
        comptime Fn = downcast[F, _Borrowing[P, R]]
        comptime assert Fn.P == P and Fn.R == R, "native borrow: incompatible signature"
        return _native_borrow[P, R, Fn](rebind[Fn](function), payload)


def _borrow_ref_call[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable,
                     F: Movable & Deinitable, raising: Bool](function: F, payload: P) raises E capturing -> R:
    return _call_native_borrow[P, R, E, F, raising](function, payload)


def _borrow_ref_call_x[P: AnyType, R: Movable & Deinitable, X: Movable & Deinitable,
                       F: Movable & Deinitable, raising: Bool](function: F, payload: P) raises X capturing -> R:
    # Sequencing's established native boundary names the error X. Rebuilding
    # that witness as E loses generic callback conformance on Mojo 1.1.
    # Only the native invocation differs; the borrowed receiver is shared.
    comptime if raising:
        comptime Fn = downcast[F, _RaisingBorrowing[P, R, X]]
        return rebind[Fn](function)[_P=P, _R=R, _X=X](payload)
    else:
        comptime assert X == Never
        comptime Fn = downcast[F, _Borrowing[P, R]]
        return rebind[Fn](function)[_P=P, _R=R](payload)


def _borrow_predicate_call[P: AnyType, S: Movable & Deinitable, X: Movable & Deinitable,
                           F: Movable & Deinitable, raising: Bool](function: F, payload: P) raises X capturing -> S:
    # Two-callback error syntax reserves A/R/E for its owned handler. Mojo 1.1
    # needs this predicate's P/S/X witness at the native call boundary; storage,
    # receiver dispatch and error propagation remain in _NativeBorrowRef.
    comptime if raising:
        comptime Fn = downcast[F, _RaisingBorrowing[P, S, X]]
        return rebind[Fn](function)[_P=P, _S=S, _X=X](payload)
    else:
        comptime assert X == Never
        comptime Fn = downcast[F, _Borrowing[P, S]]
        return rebind[Fn](function)[_P=P, _S=S](payload)


def _borrow_factory_call[Q: AnyType, S: Movable & Deinitable, Y: Movable & Deinitable,
                         F: Movable & Deinitable, raising: Bool](function: F, payload: Q) raises Y capturing -> S:
    # The second borrowing callback retains its Q/S/Y admission witness.
    comptime if raising:
        comptime Fn = downcast[F, _RaisingBorrowing[Q, S, Y]]
        return rebind[Fn](function)[_Q=Q, _S=S, _Y=Y](payload)
    else:
        comptime assert Y == Never
        comptime Fn = downcast[F, _Borrowing[Q, S]]
        return rebind[Fn](function)[_Q=Q, _S=S](payload)


@fieldwise_init
struct _NativeBorrowRef[P: AnyType, R: Movable & Deinitable, E: Movable & Deinitable,
                        F: Movable & Deinitable, raising: Bool, o: ImmOrigin,
                        admitted: Bool = False,
                        apply: def(F, P) raises E capturing -> R = _borrow_ref_call[P, R, E, F, raising]](BorrowCallable, ImplicitlyCopyable):
    """Borrow a native callback without copying its captures; invocation is shared."""
    comptime Payload = Self.P
    comptime Result = Self.R
    comptime Failure = Self.E
    var function: Pointer[Self.F, Self.o]
    def invoke(self, ref payload: Self.P) raises Self.E capturing -> Self.R:
        # Multiple native callbacks at one boundary may use different generic
        # parameter names. Such boundaries supply their admitted call directly,
        # instead of asking Mojo 1.1 to rediscover the native witness later.
        comptime if Self.admitted:
            return Self.apply(self.function[], payload)
        else:
            # Keep the established path direct. Routing it through an extra
            # function-valued generic parameter corrupts Bool predicates at O0
            # on Mojo 1.1 (covered by docs/examples/combinators.mojo).
            return _call_native_borrow[Self.P, Self.R, Self.E, Self.F, Self.raising](self.function[], payload)


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
