from fp._architecture import piped, Capture, attempt
from fp.data import Result, Ok, Err
from std.testing import assert_equal
from std.memory import ArcPointer
@fieldwise_init
struct SliceFault(Movable):
    var code: Int
from fp.callables import MutableUnary, OnceUnary, BorrowCallable, OnceThunk
@fieldwise_init
struct SliceCounter(MutableUnary):
    var count: Int
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int:
        self.count += 1
        return self.count
struct SlicePredicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Bool
    def __init__(out self): pass
    def invoke(self, ref value: Int) raises Never capturing -> Bool: return value > 1
@fieldwise_init
struct SliceOnce(OnceThunk):
    var value: Int
    comptime Out = Int
    comptime Error = SliceFault
    def call_once(deinit self) raises SliceFault -> Int: raise SliceFault(self.value)
def main() raises:
    var output = piped(List[Int]([0, 0, 0])).map(SliceCounter(0)).filter(SlicePredicate()).get()
    assert_equal(output, List[Int]([2, 3]))
    assert_equal(attempt(SliceOnce(11))._err().value.code, 11)
