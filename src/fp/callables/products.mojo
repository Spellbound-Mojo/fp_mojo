"""Move both elements out of a native pair without copying either."""
from std.builtin.rebind import rebind_var, rebind, downcast
from std.memory import MaybeUninit
from .protocols import OnceUnary, MutableUnary


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
