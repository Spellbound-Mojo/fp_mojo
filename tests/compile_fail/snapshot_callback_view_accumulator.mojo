# error: no matching method
from fp.functions import flip
from fp.iteration import iterated
from fp.callables import Binary
@fieldwise_init
struct Carry(Movable):
    var value: Int
@fieldwise_init
struct Step(Binary):
    comptime First = Int
    comptime Second = Carry
    comptime Out = Carry
    def call(self, var item: Int, var carry: Carry) -> Carry:
        carry.value += item
        return carry^
def main():
    var callback = flip(Step())
    _ = iterated(range(2)).scan_left(callback, Carry(0))
