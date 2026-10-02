# error: transformer: different inner family or error type
from fp.algebra import pure, map2_lazy
from fp.effects import State, ResultT
from fp.callables import Binary, OnceThunk
from fp.data import Result, Ok

@fieldwise_init
struct Wrong(OnceThunk):
    comptime Out = type_of(pure[State[Int]](Result[Int,UInt64](Ok(1))))
    def call_once(deinit self)->Self.Out:
        return pure[State[Int]](Result[Int,UInt64](Ok(1)))

@fieldwise_init
struct Combine(Binary):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    def call(self,var first:Int,var second:Int)->Int:
        return 0

def main():
    comptime I=ResultT[State[Int],Int]
    _=map2_lazy[I](Combine(),pure[I](1),Wrong())
