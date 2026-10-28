"""Argument binding shared by consuming and repeated callable invocation.

Native bundles pair owned arguments with a borrowed callback. Binary binding
retains its first argument and moves it on consumption or copies it per repeat.
"""
from std.builtin.rebind import downcast, rebind_var, rebind
from .invoke import call_once, call_repeated, RepeatableBinary
from .protocols import OnceThunk, BinaryContract, OnceUnary, MutableUnary, ThunkContract, UnaryContract, BorrowCallContract
from ._receiver import _borrow_once_as

@fieldwise_init
struct _BoundThunk[B: Movable & Deinitable, R: Movable & Deinitable, E: Movable & Deinitable,
                   F: Movable & Deinitable, o: ImmOrigin,
                   apply: def(F, var B) raises E thin -> R](OnceThunk):
    var arguments: Self.B
    var function: Pointer[Self.F, Self.o]
    comptime Out = Self.R
    comptime Error = Self.E
    def call_once(deinit self) raises Self.E -> Self.R:
        return Self.apply(self.function[], self.arguments^)



@fieldwise_init
struct _BindFirst[F: BinaryContract & Movable & Deinitable](
    OnceUnary, MutableUnary where RepeatableBinary[F] and conforms_to(F.First, Copyable),
    Copyable where conforms_to(F, Copyable) and conforms_to(F.First, Copyable)
):
    """A binary callback with its first argument retained; repeated calls copy it."""
    var function: Self.F
    var first: Self.F.First
    comptime Arg = Self.F.Second
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return call_once(self.function^, self.first^, arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableBinary[Self.F] and conforms_to(Self.F.First, Copyable)
        comptime C = downcast[Self.F.First, Copyable & Deinitable]
        var first = rebind_var[Self.F.First](rebind[C](self.first).copy())
        return call_repeated(self.function, first^, arg^)


# These adapters bind library receivers to the existing one-shot capture
# boundary. Native argument bundles above remain the owner of native ABI calls.
@fieldwise_init
struct _OwnedThunk[F: ThunkContract & Movable & Deinitable](OnceThunk):
    var function: Self.F
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return call_once(self.function^)


@fieldwise_init
struct _OwnedUnary[F: UnaryContract & Movable & Deinitable](OnceThunk):
    var function: Self.F
    var value: Self.F.Arg
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return call_once(self.function^, self.value^)


@fieldwise_init
struct _BorrowThunk[F: BorrowCallContract & Movable & Deinitable, o: ImmOrigin](OnceThunk):
    var function: Self.F
    var value: Pointer[Self.F.Payload, Self.o]
    comptime Out = Self.F.Result
    comptime Error = Self.F.Failure
    def call_once(deinit self) raises Self.Error -> Self.Out:
        return _borrow_once_as[Self.Error](self.value[], self.function^)
