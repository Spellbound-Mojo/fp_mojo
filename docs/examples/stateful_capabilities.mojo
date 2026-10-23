"""Select state once, then reuse a generic update through different stacks."""
from fp.effects import Stateful, LiftStateful, State, StateT, ReaderT, ResultT, modify, put, get, run
from fp.callables import Unary


@fieldwise_init
struct AddCount(Unary, Copyable):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    def call(self, var state: Int) -> Int: return state + self.amount


def add_count[C: Stateful](amount: Int) raises C.ModifyError[AddCount] -> C.Modified[AddCount] where C.StateType == Int and C.ModifyCompatible[AddCount]:
    return modify[C](AddCount(amount))


def main():
    comptime S = State[Int]
    print("state:", run[S](add_count[S](3), 10)[1])

    comptime R = ReaderT[S, String]
    comptime RC = LiftStateful[R, S]
    var base = run[R](add_count[RC](3), String("config"))
    print("under reader:", run[S](base^, 10)[1])

    comptime T = ResultT[R, String]
    comptime C = LiftStateful[T, RC]
    var nested = run[S](run[R](put[C](25), String("config")), 10)
    print("nested put:", nested[1], "; success:", nested[0].is_ok())

    # Identical state types can still be selected independently.
    comptime Two = StateT[S, Int]
    comptime Inner = LiftStateful[Two, S]
    var inner = run[S](run[Two](add_count[Inner](3), 100), 10)
    print("inner update: outer =", inner[0][1], "; inner =", inner[1])
    var outer = run[S](run[Two](add_count[Two](3), 100), 10)
    print("outer update: outer =", outer[0][1], "; inner =", outer[1])
    var read = run[S](run[Two](get[Inner](), 100), 10)
    print("selected read:", read[0][0])
