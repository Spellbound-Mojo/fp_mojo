# error: use of uninitialized value 'callback'
from fp.callables import MutableBinary
from fp.iteration import scan_left, iterated
@fieldwise_init
struct Count(MutableBinary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var carry: Int, var value: Int) -> Int:
        self.calls += 1
        return carry + value + self.calls
def main():
    var callback = Count(0)
    var pending = scan_left(range(2), 0, callback^)
    _ = callback.call_mut(0, 1)
    _ = iterated(pending^).collect_list()
