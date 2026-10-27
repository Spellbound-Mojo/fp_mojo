"""Argument binding shared by consuming and repeated callable invocation.

Native bundles pair owned arguments with a borrowed callback. Binary binding
retains its first argument and moves it on consumption or copies it per repeat.
"""
from std.builtin.rebind import downcast, rebind_var, rebind
from .invoke import call_once, call_repeated, RepeatableBinary
from .protocols import OnceThunk, BinaryContract, OnceUnary, MutableUnary

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
