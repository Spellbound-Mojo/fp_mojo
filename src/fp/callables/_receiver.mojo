"""Fixed-arity calls whose error is widened to a caller's common error type."""
from std.builtin.rebind import downcast, rebind_var, rebind
from fp._internal.errors import _ErrorCompatible, _propagate_error
from fp.callables.protocols import UnaryContract, Unary, MutableUnary, OnceUnary, BinaryContract, ThunkContract, BorrowCallContract, BorrowCallable, BorrowOnceCallable
from fp.callables.invoke import RepeatableUnary, RepeatableBinary, call_once, call_repeated, invoke_borrowed, invoke_borrowed_once


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
struct _MutableUnaryRef[F: UnaryContract & Movable & Deinitable, o: MutOrigin](MutableUnary, OnceUnary):
    """An exclusive receiver retained by a computation, without copying state."""
    var function: Pointer[Self.F, Self.o]
    comptime Arg = Self.F.Arg
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F], "the callback must be repeatable"
        return call_repeated(self.function[], arg^)
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return self.call_mut(arg^)


trait _MutableBorrow(BorrowCallContract, Movable, Deinitable):
    # Internal owned-native and factory adapters need exclusive invocation.
    # Public borrowing callbacks keep their existing shared/consuming modes.
    def invoke_mut(mut self, ref payload: Self.Payload) raises Self.Failure capturing -> Self.Result:
        ...


comptime _RepeatableBorrow[C: BorrowCallContract] = conforms_to(C, BorrowCallable) or conforms_to(C, _MutableBorrow)
comptime _OnceBorrowAvailable[C: BorrowCallContract] = conforms_to(C, BorrowOnceCallable) or _RepeatableBorrow[C]


def _borrow_repeated_as[E: Movable & Deinitable, F: BorrowCallContract & Movable & Deinitable, T: AnyType](
    ref value: T, mut function: F
) raises E -> F.Result where T == F.Payload and _ErrorCompatible[E, F.Failure] and _RepeatableBorrow[F]:
    comptime if conforms_to(F, _MutableBorrow):
        comptime D = downcast[F, _MutableBorrow]
        try:
            return rebind_var[F.Result](rebind[D](function).invoke_mut(rebind[D.Payload](value)))
        except error:
            comptime assert _ErrorCompatible[E, type_of(error)]
            _propagate_error[E](error^)
    else:
        comptime D = downcast[F, BorrowCallable]
        return rebind_var[F.Result](invoke_borrowed[E](rebind[D.Payload](value), rebind[D](function)))


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


@fieldwise_init
struct _MutableBorrowRef[F: BorrowCallContract & Movable & Deinitable, o: MutOrigin](BorrowOnceCallable):
    """Borrow one repeated receiver for a consuming invocation boundary."""
    var function: Pointer[Self.F, Self.o]
    comptime Payload = Self.F.Payload
    comptime Result = Self.F.Result
    comptime Failure = Self.F.Failure
    def invoke_once(deinit self, ref payload: Self.Payload) raises Self.Failure capturing -> Self.Result:
        comptime assert _RepeatableBorrow[Self.F]
        return _borrow_repeated_as[Self.Failure](payload, self.function[])
