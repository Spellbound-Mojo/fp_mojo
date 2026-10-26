# error: no matching method
from fp.functions import pipeline
from fp.effects import Reader, ResultT
from fp.data import Result, Ok
comptime I = ResultT[Reader[Int],String]
def on_ok(var value: Int) -> I.Pure[Int]: return I.pure(value)
def on_err(var error: String) -> I.Pure[String]: return I.pure(error^)
def main():
    _ = pipeline[I](I.pure(1)).redeem_with(on_ok,on_err).get()
