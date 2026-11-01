"""Owned carry transitions shared by lazy and eager scans."""
from std.memory import MaybeUninit
from std.builtin.rebind import downcast, rebind_var
from .products import _take_pair


struct _Carry[A: Movable & Deinitable](Movable):
    # The slot is empty while the callback owns the carry. This also makes
    # eager native-error unwinding destroy only values still owned by the scan.
    var value: Optional[Self.A]
    def __init__(out self, var initial: Self.A):
        self.value = Optional(initial^)
    def take(mut self) -> Self.A:
        return self.value.unsafe_take()
    def snapshot(self) -> Self.A where conforms_to(Self.A, Copyable):
        comptime C = downcast[Self.A, Copyable & Deinitable]
        return rebind_var[Self.A](rebind[C](self.value.value()).copy())
    def replace[Y: Movable & Deinitable](mut self, var pair: Tuple[Self.A,Y]) -> Y:
        var carry = MaybeUninit[Self.A]()
        var output = MaybeUninit[Y]()
        _take_pair(pair^, carry, output)
        self.value = Optional(carry^.unsafe_assume_init())
        return output^.unsafe_assume_init()


@fieldwise_init
struct _ScanOutputs[A: Movable & Deinitable, Y: Movable & Deinitable](Movable):
    """One owned carry and collected outputs for eager scan drivers."""
    var carry: _Carry[Self.A]
    var outputs: List[Self.Y]

    def append(mut self, var pair: Tuple[Self.A, Self.Y]):
        self.outputs.append(self.carry.replace(pair^))

    def into_result(deinit self) -> Tuple[Self.A, List[Self.Y]]:
        return (self.carry.take(), self.outputs^)
