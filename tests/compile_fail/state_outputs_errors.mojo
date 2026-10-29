# error: violated constraint
from fp.functions import pipeline
from fp.effects import StateT, inspect
from fp.algebra import IdentityFamily
from algebra_support.external import PublicMonad
def fail(value: Int) raises String -> Int: raise String("wrong")
def main():
    comptime I = StateT[PublicMonad[IdentityFamily,1],Int]
    _ = pipeline(inspect[I](fail)).run_value(0)
