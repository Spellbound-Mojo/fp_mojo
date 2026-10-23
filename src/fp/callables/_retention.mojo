"""Borrow an owned input, then pass it and the observation to one finisher."""
from std.builtin.rebind import downcast, rebind, rebind_var
from fp.callables.protocols import Unary, OnceUnary, MutableUnary, BorrowCallContract, BorrowCallable, Binary
from fp.callables.invoke import invoke_borrowed
from fp.callables._receiver import _borrow_once_as, _borrow_repeated_as, _RepeatableBorrow, _binary_once_as
from fp._internal.errors import _CommonError, _ErrorCompatible


@fieldwise_init
struct _Retain[T: Movable & Deinitable, C: BorrowCallContract & Movable & Deinitable, Finish: Binary & Defaultable](
    OnceUnary, Unary where conforms_to(C, BorrowCallable), MutableUnary where _RepeatableBorrow[C], Copyable where conforms_to(C, Copyable)
):
    """Borrow a payload for its effect and retain ownership for each success."""
    var function: Self.C
    comptime Arg = Self.T
    comptime Out = Self.Finish.Out
    comptime Error = _CommonError[Self.C.Failure, Self.Finish.Error]

    @staticmethod
    def _finish(var value: Self.T, var produced: Self.C.Result) raises Self.Error -> Self.Out:
        comptime assert Self.Finish.First == Self.T and Self.Finish.Second == Self.C.Result
        comptime assert _ErrorCompatible[Self.Error, Self.Finish.Error], "effect retention: incompatible native errors"
        return _binary_once_as[Self.Error](Self.Finish(), rebind_var[Self.Finish.First](value^), rebind_var[Self.Finish.Second](produced^))

    def call_once(deinit self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert Self.T == Self.C.Payload, "effect retention: callback must borrow the element"
        comptime assert _ErrorCompatible[Self.Error, Self.C.Failure], "effect retention: incompatible native errors"
        var produced = _borrow_once_as[Self.Error](arg, self.function^)
        return Self._finish(arg^, produced^)

    def call(self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert Self.T == Self.C.Payload, "effect retention: callback must borrow the element"
        comptime assert _ErrorCompatible[Self.Error, Self.C.Failure], "effect retention: incompatible native errors"
        comptime C = downcast[Self.C, BorrowCallable]
        var produced = rebind_var[Self.C.Result](invoke_borrowed[Self.Error](rebind[C.Payload](arg), rebind[C](self.function)))
        return Self._finish(arg^, produced^)

    def call_mut(mut self, var arg: Self.T) raises Self.Error -> Self.Out:
        comptime assert _RepeatableBorrow[Self.C]
        comptime assert Self.T == Self.C.Payload, "effect retention: callback must borrow the element"
        comptime assert _ErrorCompatible[Self.Error, Self.C.Failure], "effect retention: incompatible native errors"
        var produced = _borrow_repeated_as[Self.Error](arg, self.function)
        return Self._finish(arg^, produced^)
