# error: while loop: the predicate must read the carry
from fp.control import while_loop_mut
from fp.callables import MutableUnary, BorrowCallable
@fieldwise_init
struct Step(MutableUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_mut(mut self, var value: Int) -> Int: return value + 1
@fieldwise_init
struct Predicate(BorrowCallable):
    comptime Payload = String
    comptime Result = Bool
    def invoke(self, ref value: String) -> Bool: return True
def main():
    var body = Step()
    _ = while_loop_mut(Predicate(), body, 0)
