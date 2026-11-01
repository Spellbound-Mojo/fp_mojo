# error: no matching method
from fp.functions import pipeline
from fp.effects import Writer
from fp.algebra import StringMonoid
from fp.callables import Unary

@fieldwise_init
struct Wrong(Unary):
    comptime Arg = String
    comptime Out = Int
    def call(self, var value: String) -> Int: return value.byte_length()

def main():
    comptime W = Writer[StringMonoid]
    _ = pipeline[W](W.pure(1)).map(Wrong()).get()
