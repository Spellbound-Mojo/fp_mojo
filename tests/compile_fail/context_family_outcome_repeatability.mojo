# error: no matching method in call to 'redeem'
from fp.functions import pipeline
from fp.algebra import ListFamily
from fp.effects import ResultT
from fp.callables import OnceUnary
@fieldwise_init
struct Handler[A: Movable & Deinitable](OnceUnary):
    comptime Arg = Self.A
    comptime Out = Int
    def call_once(deinit self, var value: Self.A) -> Int: return 1
def main():
    comptime I = ResultT[ListFamily,String]
    _ = pipeline[I](I.pure(1)).redeem(Handler[Int](),Handler[String]()).get()
