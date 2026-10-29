# error: constraint
from fp.functions import pipeline
from fp.effects import Reader, ReaderT, ask, local, run
from fp.algebra import flat_map
from fp.callables import as_unary
@fieldwise_init
struct Env(Copyable, Movable):
    var value: Int
comptime R = Reader[Int]
comptime RR = ReaderT[R, Env]
def next_value(var value: Env) -> RR.Asked: return ask[RR]()
def change(value: Env) -> Env: return Env(value.value + 1)
def main():
    var scoped = pipeline(flat_map[RR](as_unary(next_value), ask[RR]())).local(change).get()
    var retained = run[RR](scoped^, Env(3))
    print(run[R](retained^, 0).value)
