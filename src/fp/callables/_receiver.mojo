"""Origin-tracked callback receivers and selected-error invocation boundaries."""
from std.builtin.rebind import downcast, rebind_var, rebind
from fp._internal.errors import _ErrorCompatible, _propagate_error
from fp.callables.protocols import CallContract, UnaryContract, Unary, MutableUnary, OnceUnary, BinaryContract, Binary, OnceBinary, MutableBinary, ThunkContract, OnceThunk, MutableThunk, BorrowCallContract, BorrowCallable, BorrowOnceCallable, BorrowMutableCallable
from fp.callables.invoke import RepeatableBorrow, invoke_borrowed_repeated, RepeatableUnary, RepeatableBinary, RepeatableThunk, call_once, call_repeated, invoke_borrowed, invoke_borrowed_once
from fp.callables.protocols import BorrowMutableCallable as _MutableBorrow
from fp.callables.invoke import RepeatableBorrow as _RepeatableBorrow, invoke_borrowed_repeated as _borrow_repeated_as


@fieldwise_init
struct _SharedBinaryRef[F: Binary, o: ImmOrigin](Binary, ImplicitlyCopyable):
    """Retain a shared receiver while transferring both operands to its call."""
    var function: Pointer[Self.F, Self.o]
    comptime First = Self.F.First
    comptime Second = Self.F.Second
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        return self.function[].call(first^, second^)


@fieldwise_init
struct _SharedUnaryRef[F: Unary, o: ImmOrigin](Unary, ImplicitlyCopyable):
    """A retained shared receiver; its output keeps the callback's own origins."""
    var function: Pointer[Self.F, Self.o]
    comptime Arg = Self.F.Arg
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call(self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return self.function[].call(arg^)


@fieldwise_init
struct _SharedBorrowRef[F: BorrowCallable, o: ImmOrigin](BorrowCallable, ImplicitlyCopyable):
    """Retain a shared receiver while borrowing each operand for its call."""
    var function: Pointer[Self.F, Self.o]
    comptime Payload = Self.F.Payload
    comptime Result = Self.F.Result
    comptime Failure = Self.F.Failure
    def invoke(self, ref payload: Self.Payload) raises Self.Failure capturing -> Self.Result:
        return self.function[].invoke(payload)


comptime _MutableUnaryRef[F: UnaryContract & Movable & Deinitable, o: MutOrigin] = MutableRef[F, o]


comptime _MutableBinaryRef[F: BinaryContract & Movable & Deinitable, o: MutOrigin] = MutableRef[F, o]


comptime _OnceBorrowAvailable[C: BorrowCallContract] = conforms_to(C, BorrowOnceCallable) or _RepeatableBorrow[C]


def _borrow_once_as[E: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable, T: AnyType](
    ref value: T, var function: F
) raises E -> F.Result where T == F.Payload and _ErrorCompatible[E, F.Failure]:
    """One borrowed-argument call; prefer a consuming receiver when available."""
    comptime if conforms_to(F, BorrowOnceCallable):
        comptime D = downcast[F, BorrowOnceCallable]
        return rebind_var[F.Result](invoke_borrowed_once[E](rebind[D.Payload](value), rebind_var[D](function^)))
    else:
        comptime assert _RepeatableBorrow[F], "borrowed callback implements no receiver mode"
        return _borrow_repeated_as[E](value, function)


# Error-adapting forms: a caller combining several callbacks raises one common
# native error. Evidence for the where clause comes from the caller's assertion.
def _unary_once_as[E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](var f: F, var arg: F.Arg
) raises E -> F.Out where _ErrorCompatible[E, F.Error]:
    try:
        return call_once(f^, arg^)
    except error:
        _propagate_error[E](error^)


def _unary_repeated_as[E: Movable & Deinitable, F: UnaryContract & Movable & Deinitable](mut f: F, var arg: F.Arg
) raises E -> F.Out where _ErrorCompatible[E, F.Error] and RepeatableUnary[F]:
    try:
        return call_repeated(f, arg^)
    except error:
        _propagate_error[E](error^)


def _binary_once_as[E: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](var f: F, var first: F.First, var second: F.Second
) raises E -> F.Out where _ErrorCompatible[E, F.Error]:
    try:
        return call_once(f^, first^, second^)
    except error:
        _propagate_error[E](error^)


def _binary_repeated_as[E: Movable & Deinitable, F: BinaryContract & Movable & Deinitable](mut f: F, var first: F.First, var second: F.Second
) raises E -> F.Out where _ErrorCompatible[E, F.Error] and RepeatableBinary[F]:
    try:
        return call_repeated(f, first^, second^)
    except error:
        _propagate_error[E](error^)


def _thunk_once_as[E: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](var f: F) raises E -> F.Out where _ErrorCompatible[E, F.Error]:
    try:
        return call_once(f^)
    except error:
        _propagate_error[E](error^)


comptime _MutableBorrowRef[F: BorrowCallContract & Movable & Deinitable, o: MutOrigin] = MutableRef[F, o]


comptime _ThunkView[F: ThunkContract & Movable & Deinitable, o: MutOrigin] = MutableRef[F, o]


def _thunk_repeated_as[E: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](mut function: F) raises E -> F.Out where _ErrorCompatible[E, F.Error] and RepeatableThunk[F]:
    try:
        return call_repeated(function)
    except error:
        _propagate_error[E](error^)


@fieldwise_init
struct MutableRef[F: Movable & Deinitable, o: MutOrigin](
    Movable, Deinitable,
    CallContract where conforms_to(F, CallContract),
    UnaryContract where conforms_to(F, CallContract) and conforms_to(F, UnaryContract),
    MutableUnary where conforms_to(F, CallContract) and conforms_to(F, UnaryContract) and RepeatableUnary[F],
    OnceUnary where conforms_to(F, CallContract) and conforms_to(F, UnaryContract) and RepeatableUnary[F],
    BinaryContract where conforms_to(F, CallContract) and conforms_to(F, BinaryContract),
    MutableBinary where conforms_to(F, CallContract) and conforms_to(F, BinaryContract) and RepeatableBinary[F],
    OnceBinary where conforms_to(F, CallContract) and conforms_to(F, BinaryContract) and RepeatableBinary[F],
    ThunkContract where conforms_to(F, CallContract) and conforms_to(F, ThunkContract),
    MutableThunk where conforms_to(F, CallContract) and conforms_to(F, ThunkContract) and RepeatableThunk[F],
    OnceThunk where conforms_to(F, CallContract) and conforms_to(F, ThunkContract) and RepeatableThunk[F],
    BorrowCallContract where conforms_to(F, BorrowCallContract),
    BorrowMutableCallable where conforms_to(F, BorrowCallContract) and RepeatableBorrow[F],
    BorrowOnceCallable where conforms_to(F, BorrowCallContract) and RepeatableBorrow[F],
):
    """An exclusive, origin-tracked reference to a repeatable library callable.

    Create one with `mut_ref(callback)`. It preserves every repeatable call
    shape of the original callback. Consuming the reference invokes the
    original repeatedly; it never consumes or copies the original state.

    Parameters:
        F: The original callback's type.
        o: The mutable origin of the original callback.
    """
    var _function: Pointer[Self.F, Self.o]
    comptime Arg = downcast[Self.F, UnaryContract & Movable & Deinitable].Arg if conforms_to(Self.F, UnaryContract) else Never
    comptime First = downcast[Self.F, BinaryContract & Movable & Deinitable].First if conforms_to(Self.F, BinaryContract) else Never
    comptime Second = downcast[Self.F, BinaryContract & Movable & Deinitable].Second if conforms_to(Self.F, BinaryContract) else Never
    comptime Out = downcast[Self.F, CallContract & Movable & Deinitable].Out if conforms_to(Self.F, CallContract) else Never
    comptime Error = downcast[Self.F, CallContract & Movable & Deinitable].Error if conforms_to(Self.F, CallContract) else Never
    comptime Payload = downcast[Self.F, BorrowCallContract & Movable & Deinitable].Payload if conforms_to(Self.F, BorrowCallContract) else Never
    comptime Result = downcast[Self.F, BorrowCallContract & Movable & Deinitable].Result if conforms_to(Self.F, BorrowCallContract) else Never
    comptime Failure = downcast[Self.F, BorrowCallContract & Movable & Deinitable].Failure if conforms_to(Self.F, BorrowCallContract) else Never

    # Generic conditional conformances retain their metadata through different
    # trait projections in Mojo 1.2. Assert identity before each rebind; the
    # existing invocation owners retain receiver priority and exact errors.
    def call_mut(mut self, var value: Self.Arg) raises Self.Error -> Self.Out where RepeatableUnary[Self.F]:
        """Invoke the original unary callback with exclusive access.

        Args:
            value: The input, consumed.

        Returns:
            The original callback's result, with its exact type and origins.

        Raises:
            `Error`, the original callback's exact error; nothing for `Never`.
        """
        comptime assert RepeatableUnary[Self.F]
        comptime C = downcast[Self.F, UnaryContract & Movable & Deinitable]
        comptime assert RepeatableUnary[C]
        comptime assert Self.Arg == C.Arg and Self.Out == C.Out and Self.Error == C.Error
        return rebind_var[Self.Out](_unary_repeated_as[Self.Error](rebind[C](self._function[]), rebind_var[C.Arg](value^)))

    def call_once(deinit self, var value: Self.Arg) raises Self.Error -> Self.Out where RepeatableUnary[Self.F]:
        """Consume this reference and invoke the original unary callback.

        Args:
            value: The input, consumed.

        Returns:
            The original callback's result, with its exact type and origins.

        Raises:
            `Error`, the original callback's exact error; nothing for `Never`.
        """
        return self.call_mut(value^)

    def call_mut(mut self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out where RepeatableBinary[Self.F]:
        """Invoke the original binary callback with exclusive access.

        Args:
            first: The first input, consumed.
            second: The second input, consumed.

        Returns:
            The original callback's result, with its exact type and origins.

        Raises:
            `Error`, the original callback's exact error; nothing for `Never`.
        """
        comptime assert RepeatableBinary[Self.F]
        comptime C = downcast[Self.F, BinaryContract & Movable & Deinitable]
        comptime assert RepeatableBinary[C]
        comptime assert Self.First == C.First and Self.Second == C.Second and Self.Out == C.Out and Self.Error == C.Error
        return rebind_var[Self.Out](_binary_repeated_as[Self.Error](rebind[C](self._function[]), rebind_var[C.First](first^), rebind_var[C.Second](second^)))

    def call_once(deinit self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out where RepeatableBinary[Self.F]:
        """Consume this reference and invoke the original binary callback.

        Args:
            first: The first input, consumed.
            second: The second input, consumed.

        Returns:
            The original callback's result, with its exact type and origins.

        Raises:
            `Error`, the original callback's exact error; nothing for `Never`.
        """
        return self.call_mut(first^, second^)

    def call_mut(mut self) raises Self.Error -> Self.Out where RepeatableThunk[Self.F]:
        """Invoke the original thunk with exclusive access.

        Returns:
            The original callback's result, with its exact type and origins.

        Raises:
            `Error`, the original callback's exact error; nothing for `Never`.
        """
        comptime assert RepeatableThunk[Self.F]
        comptime C = downcast[Self.F, ThunkContract & Movable & Deinitable]
        comptime assert RepeatableThunk[C]
        comptime assert Self.Out == C.Out and Self.Error == C.Error
        return rebind_var[Self.Out](_thunk_repeated_as[Self.Error](rebind[C](self._function[])))

    def call_once(deinit self) raises Self.Error -> Self.Out where RepeatableThunk[Self.F]:
        """Consume this reference and invoke the original thunk.

        Returns:
            The original callback's result, with its exact type and origins.

        Raises:
            `Error`, the original callback's exact error; nothing for `Never`.
        """
        return self.call_mut()

    def invoke_mut(mut self, ref value: Self.Payload) raises Self.Failure capturing -> Self.Result where RepeatableBorrow[Self.F]:
        """Invoke the original callback while borrowing its input.

        Args:
            value: The input, borrowed for this call.

        Returns:
            The original callback's result, with its exact type and origins.

        Raises:
            `Failure`, the original callback's exact error; nothing for `Never`.
        """
        comptime assert RepeatableBorrow[Self.F]
        comptime C = downcast[Self.F, BorrowCallContract & Movable & Deinitable]
        comptime assert RepeatableBorrow[C]
        comptime assert Self.Payload == C.Payload and Self.Result == C.Result and Self.Failure == C.Failure
        return rebind_var[Self.Result](invoke_borrowed_repeated[Self.Failure](rebind[C.Payload](value), rebind[C](self._function[])))

    def invoke_once(deinit self, ref value: Self.Payload) raises Self.Failure capturing -> Self.Result where RepeatableBorrow[Self.F]:
        """Consume this reference and borrow the input for the original callback.

        Args:
            value: The input, borrowed for this call.

        Returns:
            The original callback's result, with its exact type and origins.

        Raises:
            `Failure`, the original callback's exact error; nothing for `Never`.
        """
        return self.invoke_mut(value)


def mut_ref[F: Movable & Deinitable, o: MutOrigin](ref[o] function: F) -> MutableRef[F, o]:
    """Borrow a mutable callback for an operation that owns its callback.

    For example, `iterated(values^).map(mut_ref(callback)).to_list()` updates
    `callback` in place. After the operation ends, its state remains available.
    A deferred computation retains its origin until executed or discarded.

    Parameters:
        F: The callback's type, inferred.
        o: Its mutable origin, inferred.

    Args:
        function: A named library callback with a shared or mutable receiver.

    Returns:
        A movable reference preserving every repeatable call shape, exact
        argument and result types, error types, and the callback's origin.
    """
    # A body assertion also accepts generic callers that know only one shape;
    # Mojo 1.2 cannot discharge this cross-shape disjunction in a where clause.
    comptime assert RepeatableUnary[F] | RepeatableBinary[F] | RepeatableThunk[F] | RepeatableBorrow[F], "mut_ref requires a repeatable library callable"
    return MutableRef[F, o](Pointer(to=function))
