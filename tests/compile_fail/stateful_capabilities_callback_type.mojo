# error: constraint
from fp.effects import State, modify
from fp.callables import Unary
@fieldwise_init
struct Wrong(Unary, Defaultable):
    comptime Arg = Int
    comptime Out = String
    def call(self, var value: Int) -> String: return String(value)
def main(): _ = modify[State[Int]](Wrong())
