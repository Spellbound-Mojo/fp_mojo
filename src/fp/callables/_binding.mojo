"""Argument binding shared by consuming and repeated callable invocation.

Native bundles pair owned arguments with a borrowed callback. Binary binding
retains one argument and moves it on consumption or copies it per repeat.
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
struct _BindArgument[F: BinaryContract & Movable & Deinitable, first: Bool](
    OnceUnary, MutableUnary where RepeatableBinary[F] and conforms_to(F.First if first else F.Second, Copyable),
    Copyable where conforms_to(F, Copyable) and conforms_to(F.First if first else F.Second, Copyable)
):
    """Bind either binary operand; repeatability copies only the retained value."""
    var function: Self.F
    comptime Bound = Self.F.First if Self.first else Self.F.Second
    var bound: Self.Bound
    comptime Arg = Self.F.Second if Self.first else Self.F.First
    comptime Out = Self.F.Out
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime if Self.first:
            return call_once(self.function^, rebind_var[Self.F.First](self.bound^), rebind_var[Self.F.Second](arg^))
        else:
            return call_once(self.function^, rebind_var[Self.F.First](arg^), rebind_var[Self.F.Second](self.bound^))
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableBinary[Self.F] and conforms_to(Self.Bound, Copyable)
        comptime C = downcast[Self.Bound, Copyable & Deinitable]
        var bound = rebind_var[Self.Bound](rebind[C](self.bound).copy())
        comptime if Self.first:
            return call_repeated(self.function, rebind_var[Self.F.First](bound^), rebind_var[Self.F.Second](arg^))
        else:
            return call_repeated(self.function, rebind_var[Self.F.First](arg^), rebind_var[Self.F.Second](bound^))


comptime _BindFirst[F: BinaryContract & Movable & Deinitable] = _BindArgument[F, True]
comptime _BindSecond[F: BinaryContract & Movable & Deinitable] = _BindArgument[F, False]


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
