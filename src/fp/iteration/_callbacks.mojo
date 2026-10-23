"""Signature-specific native application bridges for terminal and lazy algorithms.

The caller's function stays in place. Terminal bridges retain the native read
calling convention; terminal drivers carry typed pointers to the borrowed
function until this boundary. Lazy adapters own their callback, so they call a
native callback through the iterator's mutable access: calling a callback with
owned mutable captures through a read borrow loses its state updates at O3 on
the pinned compiler. Specialization preserves type and origin, without storing a
copy of the callable state. Pure application uses Never in the same execution
kernel as typed failures.
"""

from std.builtin.rebind import downcast, rebind_var
from fp.callables.native import _LazyUnary, _LazyOptional
from fp.data.control import ControlFlow
from fp.callables.protocols import BorrowCallable, Unary, UnaryContract, Binary
from fp.callables.invoke import BorrowCallCompatible, invoke_borrowed, RepeatableUnary
from fp.callables._receiver import _unary_repeated_as, _binary_repeated_as


# Native signature traits used at lazy-adapter construction. Iterator storage
# retains F with ordinary value constraints; a function-trait constraint on the
# struct itself adds a capturing effect incompatible with native Iterator.
comptime _LazyStep[A: Copyable & Deinitable, T: Movable & Deinitable] = def(var A, var T) -> A


def _call_lazy_step[A: Copyable & Deinitable, T: Movable & Deinitable,
                    F: _LazyStep[A, T]](mut function: F, var accumulator: A, var value: T) -> A:
    return function(accumulator^, value^)


def _call_lazy_unary[T: Movable & Deinitable, U: Movable & Deinitable,
                     F: _LazyUnary[T, U]](mut function: F, var value: T) -> U:
    return function(value^)


def _apply_lazy_unary[T: Movable & Deinitable, U: Movable & Deinitable,
                      F: Movable & Deinitable](mut function: F, var value: T) -> U:
    comptime if conforms_to(F, UnaryContract):
        comptime C = downcast[F, UnaryContract & Movable & Deinitable]
        comptime assert RepeatableUnary[C] and C.Error == Never and C.Arg == T and C.Out == U, "map: exact non-raising unary callable required"
        return rebind_var[U](_unary_repeated_as[Never](rebind[C](function), rebind_var[C.Arg](value^)))
    elif conforms_to(F, _LazyUnary[T, U]):
        comptime Fn = downcast[F, _LazyUnary[T, U]]
        comptime assert conforms_to(Fn, _LazyUnary[T, U]), "map: incompatible native callback signature"
        return _call_lazy_unary[T, U, Fn](rebind[Fn](function), value^)
    else:
        comptime assert F == def(var T) thin -> U, "map: non-raising native callback required"
        return rebind[def(var T) thin -> U](function)(value^)


def _apply_lazy_step[A: Copyable & Deinitable, T: Movable & Deinitable,
                     F: Movable & Deinitable](mut function: F, var accumulator: A, var value: T) -> A:
    comptime if conforms_to(F, Binary):
        comptime C = downcast[F, Binary]
        comptime assert C.Error == Never and C.First == A and C.Second == T and C.Out == A, "scan_left: exact non-raising binary callable required"
        return rebind_var[A](_binary_repeated_as[Never](
            rebind[C](function), rebind_var[C.First](accumulator^), rebind_var[C.Second](value^)))
    elif conforms_to(F, _LazyStep[A, T]):
        comptime Fn = downcast[F, _LazyStep[A, T]]
        comptime assert conforms_to(Fn, _LazyStep[A, T]), "scan_left: incompatible native callback signature"
        return _call_lazy_step[A, T, Fn](rebind[Fn](function), accumulator^, value^)
    else:
        comptime assert F == def(var A, var T) thin -> A, "scan_left: non-raising native callback required"
        return rebind[def(var A, var T) thin -> A](function)(accumulator^, value^)


comptime _LazyPredicate[T: Movable & Deinitable] = def(T) -> Bool


def _call_lazy_predicate[T: Movable & Deinitable, F: _LazyPredicate[T]](
    mut function: F, value: T
) -> Bool:
    return function(value)


def _apply_lazy_predicate[T: Movable & Deinitable, F: Movable & Deinitable](
    mut function: F, value: T
) -> Bool:
    comptime if conforms_to(F, BorrowCallable):
        comptime C = downcast[F, BorrowCallable]
        comptime assert C.Failure == Never, "filter: non-raising callable required"
        return _predicate_callable[T, C, Never](value, rebind[C](function))
    elif conforms_to(F, _LazyPredicate[T]):
        comptime Fn = downcast[F, _LazyPredicate[T]]
        comptime assert conforms_to(Fn, _LazyPredicate[T]), "filter: incompatible native predicate signature"
        return _call_lazy_predicate[T, Fn](rebind[Fn](function), value)
    else:
        comptime assert F == def(T) thin -> Bool, "filter: non-raising native predicate required"
        return rebind[def(T) thin -> Bool](function)(value)


def _apply_lazy_optional[T: Movable & Deinitable, U: Movable & Deinitable,
                         F: Movable & Deinitable](mut function: F, var value: T) -> Optional[U]:
    comptime if conforms_to(F, Unary):
        comptime C = downcast[F, Unary]
        comptime assert C.Error == Never and C.Arg == T and C.Out == Optional[U], "filter_map: exact non-raising unary callable required"
        return rebind_var[Optional[U]](_unary_repeated_as[Never](rebind[C](function), rebind_var[C.Arg](value^)))
    elif conforms_to(F, _LazyOptional[T, U]):
        comptime Fn = downcast[F, _LazyOptional[T, U]]
        comptime assert conforms_to(Fn, _LazyOptional[T, U]), "filter_map: incompatible native callback signature"
        # Mojo 1.2 carries the structural callback signature through conformance.
        return rebind_var[Optional[U]](_call_lazy_unary[T, Optional[U], Fn](
            rebind[Fn](function), rebind_var[T](value^)
        ))
    else:
        comptime assert F == def(var T) thin -> Optional[U], "filter_map: non-raising native callback required"
        return rebind[def(var T) thin -> Optional[U]](function)(value^)


def _binary_plain[A: Movable & Deinitable, T: Movable & Deinitable,
                  R: Movable & Deinitable, F: def(var A, var T) -> R](
    var accumulator: A, var value: T, function: F
) capturing -> R:
    return function(accumulator^, value^)


def _binary_raising[A: Movable & Deinitable, T: Movable & Deinitable,
                    R: Movable & Deinitable, E: AnyType,
                    F: def(var A, var T) raises E -> R](
    var accumulator: A, var value: T, function: F
) raises E capturing -> R:
    return function(accumulator^, value^)


def _predicate_plain[T: Movable & Deinitable, F: def(T) -> Bool](
    value: T, function: F
) capturing -> Bool:
    return function(value)


def _predicate_raising[T: Movable & Deinitable, E: AnyType,
                       F: def(T) raises E -> Bool](
    value: T, function: F
) raises E capturing -> Bool:
    return function(value)


def _control_plain[A: Movable & Deinitable, B: Movable & Deinitable,
                   T: Movable & Deinitable,
                   F: def(var A, var T) -> ControlFlow[B, A]](
    var accumulator: A, var value: T, function: F
) capturing -> ControlFlow[B, A]:
    # Keep the structural result in the signature: the compiler pin cannot
    # prove its equality through a bridge with an independent result type.
    return function(accumulator^, value^)


def _control_raising[A: Movable & Deinitable, B: Movable & Deinitable,
                     T: Movable & Deinitable, E: AnyType,
                     F: def(var A, var T) raises E -> ControlFlow[B, A]](
    var accumulator: A, var value: T, function: F
) raises E capturing -> ControlFlow[B, A]:
    return function(accumulator^, value^)


# Terminal bridges for shared-receiver fixed-arity callables, such as partials.
def _binary_fixed[A: Movable & Deinitable, T: Movable & Deinitable, F: Binary](
    var accumulator: A, var value: T, function: F
) raises F.Error capturing -> A:
    comptime assert F.First == A and F.Second == T and F.Out == A, "fold: step must take and return the accumulator"
    return rebind_var[A](function.call(rebind_var[F.First](accumulator^), rebind_var[F.Second](value^)))


def _control_fixed[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, F: Binary](
    var accumulator: A, var value: T, function: F
) raises F.Error capturing -> ControlFlow[B, A]:
    comptime assert F.First == A and F.Second == T and F.Out == ControlFlow[B, A], "fold_until: step must return exact ControlFlow"
    return rebind_var[ControlFlow[B, A]](function.call(rebind_var[F.First](accumulator^), rebind_var[F.Second](value^)))


def _predicate_callable[T: Movable & Deinitable, C: BorrowCallable, E: Movable & Deinitable = C.Failure](
    value: T, function: C
) raises E capturing -> Bool:
    comptime assert BorrowCallCompatible[E, C, T] and C.Result == Bool, "predicate: exact payload, Bool result and compatible error required"
    return rebind_var[Bool](invoke_borrowed[E](value, function))


# The lazy binary bridge needs mutable access to owned native captures, unlike
# terminal native calls. Pair unpacking and library receiver dispatch remain
# owned by callables, as for the other lazy invocation shapes.
from fp.callables.native import _Binary
from fp.callables.protocols import BinaryContract
from fp.callables.invoke import RepeatableBinary
from fp.callables.products import _take_pair
from std.memory import MaybeUninit


def _call_lazy_binary[A: Movable & Deinitable, B: Movable & Deinitable,
                      R: Movable & Deinitable, F: _Binary[A, B, R]](
    mut function: F, var first: A, var second: B
) -> R:
    return function(first^, second^)


comptime _IndexedBinary[T: Movable & Deinitable, R: Movable & Deinitable] = def(var Int, var T) -> R


def _call_lazy_indexed[T: Movable & Deinitable, R: Movable & Deinitable,
                       F: _IndexedBinary[T, R]](mut function: F, index: Int, var value: T) -> R:
    return function(index, value^)


def _apply_lazy_indexed[T: Movable & Deinitable, R: Movable & Deinitable,
                        F: Movable & Deinitable](mut function: F, index: Int, var value: T) -> R:
    comptime if F == def(var Int, var T) thin -> R:
        return rebind[def(var Int, var T) thin -> R](function)(index, value^)
    else:
        comptime Fn = downcast[F, _IndexedBinary[T, R]]
        comptime assert conforms_to(Fn, _IndexedBinary[T, R])
        return _call_lazy_indexed[T, R, Fn](rebind[Fn](function), index, value^)


# Tuple adaptation is an invocation policy of the same _Map driver. Store
# the actual callback directly; its exact type preserves native origins and
# mutable receiver access without introducing a second callable wrapper.
def _apply_lazy_pair[A: Movable & Deinitable, B: Movable & Deinitable,
                     R: Movable & Deinitable, F: Movable & Deinitable, indexed: Bool](
    mut function: F, var arg: Tuple[A, B]
) -> R:
    var left = MaybeUninit[A]()
    var right = MaybeUninit[B]()
    _take_pair(arg^, left, right)
    var first = left^.unsafe_assume_init()
    var second = right^.unsafe_assume_init()
    comptime if conforms_to(F, BinaryContract):
        comptime C = downcast[F, BinaryContract & Movable & Deinitable]
        comptime assert RepeatableBinary[C] and C.Error == Never and C.First == A and C.Second == B and C.Out == R
        return rebind_var[R](_binary_repeated_as[Never](rebind[C](function), rebind_var[C.First](first^), rebind_var[C.Second](second^)))
    elif F == def(var A, var B) thin -> R:
        return rebind[def(var A, var B) thin -> R](function)(first^, second^)
    elif indexed:
        # Literal-Int and fully generic binary signatures have distinct native
        # witness tables on Mojo 1.1. Only their invocation boundary differs.
        comptime assert A == Int
        return _apply_lazy_indexed[B, R](function, rebind_var[Int](first^), second^)
    else:
        comptime Fn = downcast[F, _Binary[A, B, R]]
        comptime assert conforms_to(Fn, _Binary[A, B, R])
        return _call_lazy_binary[A, B, R, Fn](rebind[Fn](function), first^, second^)


comptime _LazyScanStep[A: Movable & Deinitable, T: Movable & Deinitable, Y: Movable & Deinitable] = def(var A, var T) -> Tuple[A,Y]


def _call_lazy_scan[A: Movable & Deinitable, T: Movable & Deinitable,
                    Y: Movable & Deinitable, F: _LazyScanStep[A,T,Y]](
    mut function: F, var carry: A, var value: T
) -> Tuple[A,Y]:
    # Keep the structural pair in the native signature. This mutable receiver
    # preserves owned capture updates; eager control.scan borrows its callback.
    return function(carry^, value^)


def _apply_lazy_scan[A: Movable & Deinitable, T: Movable & Deinitable,
                     Y: Movable & Deinitable, F: Movable & Deinitable](
    mut function: F, var carry: A, var value: T
) -> Tuple[A,Y]:
    from fp.callables.protocols import BinaryContract
    from fp.callables.invoke import RepeatableBinary
    comptime if conforms_to(F, BinaryContract):
        comptime C = downcast[F, BinaryContract & Movable & Deinitable]
        comptime assert RepeatableBinary[C] and C.Error == Never and C.First == A and C.Second == T and C.Out == Tuple[A,Y], "scan_map: exact non-raising repeatable binary callable required"
        return rebind_var[Tuple[A,Y]](_binary_repeated_as[Never](rebind[C](function),rebind_var[C.First](carry^),rebind_var[C.Second](value^)))
    elif conforms_to(F, _LazyScanStep[A,T,Y]):
        comptime Fn = downcast[F, _LazyScanStep[A,T,Y]]
        comptime assert conforms_to(Fn, _LazyScanStep[A,T,Y]), "scan_map: incompatible native callback signature"
        return _call_lazy_scan[A,T,Y,Fn](rebind[Fn](function),carry^,value^)
    else:
        comptime assert F == def(var A,var T) thin -> Tuple[A,Y], "scan_map: non-raising native callback required"
        return rebind[def(var A,var T) thin -> Tuple[A,Y]](function)(carry^,value^)


def _snapshot_step[A: Copyable & Deinitable, T: Movable & Deinitable,
                   F: Movable & Deinitable](mut function: F, var carry: A, var value: T) -> Tuple[A,A]:
    var updated = _apply_lazy_step[A,T](function,carry^,value^)
    var snapshot = updated.copy()
    return (updated^, snapshot^)
