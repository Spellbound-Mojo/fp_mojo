# error: no matching method
from fp.functions import pipeline
from fp.algebra import ValidationFamily, ListMonoid
comptime I = ValidationFamily[ListMonoid[String]]
def on_ok(var value: Int) -> I.Pure[Int]: return I.pure(value)
def on_err(var error: List[String]) -> I.Pure[Int]: return I.pure(2)
def main():
    _ = pipeline[I](I.pure(1)).redeem_with(on_ok,on_err).get()
