# error: no matching method
from fp.functions import pipeline
from fp.data import Result, Ok
from outcome_admission_support import Restricted
comptime I = Restricted[True,True,True,False]
def on_ok(var value: Int) -> Int: return value
def on_err(var error: String) -> Int: return 2
def main():
    _ = pipeline[I](I.pure(1)).redeem(on_ok,on_err).get()
