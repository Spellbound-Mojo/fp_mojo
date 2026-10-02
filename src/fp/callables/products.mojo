"""Move both elements out of a native pair without copying either."""
from std.builtin.rebind import rebind_var
from std.memory import MaybeUninit


def _take_pair[A: Movable & Deinitable, B: Movable & Deinitable](
    var pair: Tuple[A, B], mut first: MaybeUninit[A], mut second: MaybeUninit[B]
):
    """Move both elements of a native pair into uninitialized caller slots.

    Untagged slots keep the split to plain moves. Each caller takes both slots
    with `unsafe_assume_init` immediately afterwards."""
    def put[index: Int](var value: Tuple[A, B].Ts[index]) capturing:
        comptime if index == 0:
            first.unsafe_ptr().unsafe_write(rebind_var[A](value^))
        else:
            second.unsafe_ptr().unsafe_write(rebind_var[B](value^))
    pair^.consume_elements[put]()
