"""Move both elements out of a native pair without copying either."""
from std.builtin.rebind import rebind_var, rebind, downcast
from std.memory import MaybeUninit
from .protocols import UnaryContract, OnceUnary, MutableUnary
from .invoke import call_once, RepeatableUnary
from ._receiver import _MutableUnaryRef


comptime _OptionalCell[T: Movable & Deinitable]: Movable & Deinitable = Optional[T]

def _take_pair[A: Movable & Deinitable, B: Movable & Deinitable](
    var pair: Tuple[A, B], mut first: MaybeUninit[A], mut second: MaybeUninit[B]
):
    """Move both elements of a native pair into uninitialized caller slots.

    Untagged slots keep the split to plain moves. Each caller takes both slots
    with `unsafe_assume_init` immediately afterwards."""
    def put[index: Int](var value: Tuple[A, B].Ts[index]) {ref first, ref second}:
        comptime if index == 0:
            first.unsafe_ptr().unsafe_write(rebind_var[A](value^))
        else:
            second.unsafe_ptr().unsafe_write(rebind_var[B](value^))
    pair^.consume_elements(put)


@fieldwise_init
struct _WithSecond[A: Movable & Deinitable, S: Movable & Deinitable](OnceUnary, MutableUnary where conforms_to(S, Copyable)):
    """Pair each base payload with an owned second value; repeated pairing copies it."""
    var second: Self.S
    comptime Arg = Self.A
    comptime Out = Tuple[Self.A, Self.S]
    def call_once(deinit self, var arg: Self.Arg) -> Self.Out:
        return Tuple(arg^, self.second^)
    def call_mut(mut self, var arg: Self.Arg) -> Self.Out:
        comptime C = downcast[Self.S, Copyable & Deinitable]
        return Tuple(arg^, rebind_var[Self.S](rebind[C](self.second).copy()))


@fieldwise_init
struct _MapPair[F: UnaryContract & Movable & Deinitable, Other: Movable & Deinitable, first: Bool](
    OnceUnary, MutableUnary where RepeatableUnary[F], Copyable where conforms_to(F, Copyable)
):
    """Map one native pair component, moving the untouched component unchanged."""
    var function: Self.F
    comptime Arg = Tuple[Self.F.Arg, Self.Other] if Self.first else Tuple[Self.Other, Self.F.Arg]
    comptime Out = Tuple[Self.F.Out, Self.Other] if Self.first else Tuple[Self.Other, Self.F.Out]
    comptime Error = Self.F.Error
    def call_once(deinit self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        return _map_pair[Self.Other, Self.first](self.function^, arg^)
    def call_mut(mut self, var arg: Self.Arg) raises Self.Error -> Self.Out:
        comptime assert RepeatableUnary[Self.F]
        return _map_pair[Self.Other, Self.first](_MutableUnaryRef(Pointer(to=self.function)), arg^)


def _map_pair[Other: Movable & Deinitable, first: Bool, F: UnaryContract & Movable & Deinitable](
    var function: F, var pair: _MapPair[F, Other, first].Arg
) raises F.Error -> _MapPair[F, Other, first].Out:
    var value_slot = MaybeUninit[F.Arg]()
    var other_slot = MaybeUninit[Other]()
    comptime if first:
        _take_pair(rebind_var[Tuple[F.Arg, Other]](pair^), value_slot, other_slot)
    else:
        _take_pair(rebind_var[Tuple[Other, F.Arg]](pair^), other_slot, value_slot)
    var value = value_slot^.unsafe_assume_init()
    var other = other_slot^.unsafe_assume_init()
    var mapped = call_once(function^, value^)
    comptime if first:
        return rebind_var[_MapPair[F, Other, first].Out](Tuple(mapped^, other^))
    else:
        return rebind_var[_MapPair[F, Other, first].Out](Tuple(other^, mapped^))
