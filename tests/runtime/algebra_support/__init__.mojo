"""Shared native values and callbacks for algebra/effect contracts."""
from fp.callables import Binary, OnceThunk
from fp.callables.products import _take_pair
from std.memory import MaybeUninit


def ints(*values: Int) -> List[Int]:
    var result = List[Int]()
    for value in values:
        result.append(value)
    return result^


def increment(var value: Int) -> Int:
    return value + 1


@fieldwise_init
struct Add(Binary, Copyable, Defaultable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self, var first: Int, var second: Int) -> Int:
        return first + second


@fieldwise_init
struct Next[T: Movable & Deinitable](OnceThunk):
    var value: Self.T
    comptime Out = Self.T
    def call_once(deinit self) -> Self.T:
        return self.value^


def split_pair[A: Movable & Deinitable, B: Movable & Deinitable](
    var pair: Tuple[A, B], mut first: Optional[A], mut second: Optional[B]
):
    """Move both elements of a possibly move-only pair into empty Optionals."""
    var left = MaybeUninit[A]()
    var right = MaybeUninit[B]()
    _take_pair(pair^, left, right)
    first = Optional(left^.unsafe_assume_init())
    second = Optional(right^.unsafe_assume_init())
