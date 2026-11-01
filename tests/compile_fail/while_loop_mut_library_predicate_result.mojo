# error: while loop: the predicate must return Bool
from fp.control import while_loop_mut
from fp.callables import MutableUnary, BorrowCallable
@fieldwise_init
struct Step(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int: return value + 1
@fieldwise_init
struct Predicate(BorrowCallable):
    comptime Payload = Int
    comptime Result = Int
    def invoke(self, ref value: Int) -> Int: return value
def main():
    var body = Step()
    _ = while_loop_mut(Predicate(), body, 0)
