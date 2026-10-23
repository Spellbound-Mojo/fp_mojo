# error: use of uninitialized value
from fp.effects import State, ResultT, LiftStateful, modify
from fp.callables import OnceUnary
@fieldwise_init
struct Update(OnceUnary):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var state: Int) -> Int: return state + self.amount
def main():
    comptime S = State[Int]
    comptime C = LiftStateful[ResultT[S, String], S]
    var callback = Update(1)
    _ = modify[C](callback^)
    _ = modify[C](callback^)
