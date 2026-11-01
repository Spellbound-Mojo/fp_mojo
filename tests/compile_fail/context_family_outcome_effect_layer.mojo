# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, ResultT
from fp.data import Result, Ok
comptime I = ResultT[Reader[Int],String]
comptime Wrong = ResultT[Reader[Int],Int]
def on_ok(var value: Int) -> Wrong.Pure[Int]: return Wrong.pure(value)
def on_err(var error: String) -> Wrong.Pure[Int]: return Wrong.pure(2)
def main():
    _ = pipeline[I](I.pure(1)).redeem_with(on_ok,on_err).get()
