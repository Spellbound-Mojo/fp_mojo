"""Element transformations shared by eager families and lazy adapters."""
from std.builtin.rebind import downcast, rebind_var
from .protocols import UnaryContract, Unary, MutableUnary, OnceUnary, BorrowCallable, BorrowCallContract, BorrowOnceCallable, ThunkContract, OnceThunk, Binary
from .invoke import invoke_borrowed, call_once, call_repeated, RepeatableThunk
from ._receiver import _borrow_once_as, _borrow_repeated_as, _RepeatableBorrow, _MutableBorrow
from .native import _Borrowing, _call_lazy_borrow
from .products import _OptionalCell


@fieldwise_init
struct _ValueThunk[T: Movable & Deinitable](OnceThunk, Copyable where conforms_to(T, Copyable)):
    """An already computed operand, moved out at most once."""
    var value: Self.T
    comptime Out = Self.T
    comptime Error = Never
    def call_once(deinit self) -> Self.Out:
        return self.value^


@fieldwise_init
struct _Pair[A: Movable & Deinitable, B: Movable & Deinitable](Binary, Copyable, Defaultable):
    comptime First = Self.A
    comptime Second = Self.B
    comptime Out = Tuple[Self.A, Self.B]
    def call(self, var first: Self.A, var second: Self.B) -> Self.Out:
        return (first^, second^)


@fieldwise_init
struct _Apply[U: UnaryContract & Movable & Deinitable](Binary, Copyable, Defaultable):
    """Call the left element, a unary callback, with the right element."""
    comptime First = Self.U
    comptime Second = Self.U.Arg
    comptime Out = Self.U.Out
    comptime Error = Self.U.Error
    def call(self, var first: Self.First, var second: Self.Second) raises Self.Error -> Self.Out:
        return call_once(first^, second^)


@fieldwise_init
struct _Fill[T: Movable & Deinitable, U: Copyable & Deinitable](Unary):
    var value: Self.U
    comptime Arg = Self.T
    comptime Out = Self.U
    def call(self, var arg: Self.T) -> Self.U:
        return self.value.copy()


@fieldwise_init
struct _Replace[T: Copyable & Equatable & Deinitable](Unary):
    var old: Self.T
    var new: Self.T
    comptime Arg = Self.T
    comptime Out = Self.T
    def call(self, var arg: Self.T) -> Self.T:
        if arg == self.old:
            return self.new.copy()
        return arg^


@fieldwise_init
struct _TupleWith[T: Movable & Deinitable, U: Copyable & Deinitable, left: Bool](Unary):
    var value: Self.U
    comptime Arg = Self.T
    comptime Out = Tuple[Self.U, Self.T] if Self.left else Tuple[Self.T, Self.U]
    def call(self, var arg: Self.T) -> Self.Out:
        comptime if Self.left:
            return rebind_var[Self.Out]((self.value.copy(), arg^))
        else:
            return rebind_var[Self.Out]((arg^, self.value.copy()))


def _selected[T: Movable & Deinitable](var value: T, accepted: Bool) -> Optional[T]:
    if accepted:
        return Optional(value^)
    return None


def _observed[T: Movable & Deinitable, U: Movable & Deinitable, paired: Bool, selected: Bool = False](
    var value: T, var result: U
) -> Optional[T] if selected else Tuple[T, U] if paired else T:
    comptime Out = Optional[T] if selected else Tuple[T, U] if paired else T
    comptime if selected:
        comptime assert U == Bool and not paired, "effectful filter: Bool decision required"
        return rebind_var[Out](_selected(value^, rebind[Bool](result)))
    elif paired:
        return rebind_var[Out]((value^, result^))
    else:
        return rebind_var[Out](value^)


@fieldwise_init
struct _BorrowedUnary[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable](
    OnceUnary, MutableUnary where _RepeatableBorrow[C], Copyable where conforms_to(C, Copyable)
):
    """Call a borrowed projection on one owned input, then discard the input.

    Materialize the result before releasing the input. Mojo 1.2 mislowers a
    tail-returned borrow of a consumed register value at O0; this explicit
    evaluation order also matches the shared retention adapter.
    """
    var function: Self.C
    comptime Arg = Self.T
    comptime Out = Self.C.Result
    comptime Error = Self.C.Failure
    def call_once(deinit self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert Self.C.Payload == Self.T
        var result = _borrow_once_as[Self.Error](arg, self.function^)
        return result^
    def call_mut(mut self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert Self.C.Payload == Self.T
        comptime assert _RepeatableBorrow[Self.C]
        var result = _borrow_repeated_as[Self.Error](arg, self.function)
        return result^


@fieldwise_init
struct _Retained[T: Movable & Deinitable, U: Movable & Deinitable, paired: Bool, selected: Bool = False](
    OnceUnary, MutableUnary where conforms_to(T, Copyable), Copyable where conforms_to(T, Copyable)
):
    """Retain one payload, optionally paired or selected by an effect's Bool."""
    var value: Self.T
    comptime Arg = Self.U
    comptime Out = Optional[Self.T] if Self.selected else Tuple[Self.T, Self.U] if Self.paired else Self.T
    def call_once(deinit self, var arg: Self.U) -> Self.Out:
        return _observed[Self.T, Self.U, Self.paired, Self.selected](self.value^, arg^)
    def call_mut(mut self, var arg: Self.U) -> Self.Out:
        # A branching target needs one retained value per successful branch.
        # Single-use targets still select call_once and move the original.
        comptime TCopy = downcast[Self.T, Copyable & Deinitable]
        return _observed[Self.T, Self.U, Self.paired, Self.selected](rebind_var[Self.T](rebind[TCopy](self.value).copy()), arg^)


@fieldwise_init
struct _IgnoreInput[T: Movable & Deinitable, F: ThunkContract & Movable & Deinitable](
    OnceUnary, BorrowOnceCallable, MutableUnary where RepeatableThunk[F],
    _MutableBorrow where RepeatableThunk[F], Copyable where conforms_to(F, Copyable)
):
    """Turn a zero-argument factory into an owned or borrowed continuation."""
    var function: Self.F
    comptime Arg = Self.T
    comptime Payload = Self.T
    comptime Out = Self.F.Out
    comptime Result = Self.F.Out
    comptime Error = Self.F.Error
    comptime Failure = Self.F.Error
    def call_once(deinit self, var arg: Self.T) raises Self.Error -> Self.Out:
        return call_once(self.function^)
    def invoke_once(deinit self, ref payload: Self.T) raises Self.Failure capturing -> Self.Result:
        return call_once(self.function^)
    def call_mut(mut self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert RepeatableThunk[Self.F]
        return call_repeated(self.function)
    def invoke_mut(mut self, ref payload: Self.T) raises Self.Failure capturing -> Self.Result:
        comptime assert RepeatableThunk[Self.F]
        return call_repeated(self.function)


@fieldwise_init
struct _ObserveOnce[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, paired: Bool](
    OnceUnary, MutableUnary where _RepeatableBorrow[C], Copyable where conforms_to(C, Copyable)
):
    """Observe one borrowed payload, retaining ownership for the output."""
    var function: Self.C
    comptime Arg = Self.T
    comptime Out = Tuple[Self.T, Self.C.Result] if Self.paired else Self.T
    comptime Error = Self.C.Failure
    def call_once(deinit self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert Self.C.Payload == Self.T
        var result = _borrow_once_as[Self.Error](arg, self.function^)
        return _observed[Self.T, Self.C.Result, Self.paired](arg^, result^)

    def call_mut(mut self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert Self.C.Payload == Self.T and _RepeatableBorrow[Self.C]
        var result = _borrow_repeated_as[Self.Error](arg, self.function)
        return _observed[Self.T, Self.C.Result, Self.paired](arg^, result^)


@fieldwise_init
struct _Observe[T: Movable & Deinitable, C: BorrowCallable, paired: Bool](Unary):
    var function: Self.C
    comptime Arg = Self.T
    comptime Out = Tuple[Self.T, Self.C.Result] if Self.paired else Self.T
    comptime Error = Self.C.Failure
    def call(self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert Self.C.Payload == Self.T
        var result = invoke_borrowed[Self.Error](arg, self.function)
        return _observed[Self.T, Self.C.Result, Self.paired](arg^, result^)


@fieldwise_init
struct _ObserveNative[P: AnyType, R: Movable & Deinitable,
                      F: Movable & Deinitable, paired: Bool](MutableUnary):
    # Retain the admitted native signature in storage: a plain F field loses
    # its destruction witness when the callback returns an origin-bound value.
    comptime Native = downcast[Self.F, _Borrowing[Self.P, Self.R]]
    var function: _OptionalCell[Self.Native]
    def __init__(out self, var function: Self.F):
        self.function = Optional(rebind_var[Self.Native](function^))
    comptime Arg = downcast[Self.P, Movable & Deinitable]
    comptime Out = Tuple[downcast[Self.P, Movable & Deinitable], Self.R] if Self.paired else downcast[Self.P, Movable & Deinitable]
    def call_mut(mut self, var arg: downcast[Self.P, Movable & Deinitable]) -> Self.Out:
        comptime Fn = downcast[Self.F, _Borrowing[Self.P, Self.R]]
        comptime assert conforms_to(Fn, _Borrowing[Self.P, Self.R])
        var result = _call_lazy_borrow[Self.P, Self.R, Fn](rebind[Fn](self.function.value()), arg)
        return _observed[downcast[Self.P, Movable & Deinitable], Self.R, Self.paired](arg^, result^)
