# error: invalid call to 'get_ref'
from fp.effects import get_ref
from fp.effects.async_runtime import Async, Ref


@fieldwise_init
struct Box(Movable):
    var value: Int


def main():
    # Reading copies the state, so a move-only cell has no get.
    var cell = Ref(Box(1))
    _ = get_ref[Async[Int], Box](cell)
