# error: use of uninitialized value 'callback'
from fp.callables import MutableThunk
from fp.data import attempt_once
@fieldwise_init
struct Counter(MutableThunk):
    comptime Out = Int
    var calls: Int
    def call_mut(mut self) -> Int:
        self.calls += 1
        return self.calls
def main():
    var callback = Counter(0)
    _ = attempt_once(callback^)
    print(callback.calls)
