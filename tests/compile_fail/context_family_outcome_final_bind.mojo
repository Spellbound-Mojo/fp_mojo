# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok
from outcome_admission_support import Restricted
comptime I = Restricted[True,True,False,True]
def on_ok(var value: Int) -> Result[Int,String]: return Ok(value)
def on_err(var error: String) -> Result[Int,String]: return Ok(2)
def main():
    _ = pipeline[I](I.pure(1)).redeem_with(on_ok,on_err).get()
