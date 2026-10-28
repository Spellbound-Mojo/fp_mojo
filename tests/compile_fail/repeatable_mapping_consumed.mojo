# error: use of uninitialized value 'callback'
from fp.callables import MutableUnary
from fp.iteration import iterated
@fieldwise_init
struct Count(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var value: Int) -> Int:
        self.calls += 1
        return value + self.calls
def main():
    var callback = Count(0)
    var pending = iterated(range(2)).map(callback^)
    _ = callback.call_mut(1)
    _ = pending^.collect_list()
