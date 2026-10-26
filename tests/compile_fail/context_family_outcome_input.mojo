# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, ResultT
from fp.data import Result, Ok
comptime I = ResultT[Reader[Int],String]
def on_ok(var value: String) -> Int: return 1
def on_err(var error: String) -> Int: return 2
def main():
    _ = pipeline[I](I.pure(1)).redeem(on_ok,on_err).get()
