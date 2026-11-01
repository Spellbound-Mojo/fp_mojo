# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, ResultT
from fp.data import Result, Ok
comptime I = ResultT[Reader[Int],String]
from fp.callables import Unary
@fieldwise_init
struct OnOk(Unary):
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Int
    def call(self, var value: Int) raises Int -> Int: raise value
@fieldwise_init
struct OnErr(Unary):
    comptime Arg = String
    comptime Out = Int
    comptime Error = String
    def call(self, var error: String) raises String -> Int: raise error^
def main():
    _ = pipeline[I](I.pure(1)).redeem(OnOk(),OnErr()).get()
