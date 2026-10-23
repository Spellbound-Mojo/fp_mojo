# error: constraint
from fp.functions import piped
from fp.callables import as_unary
def increment(x: Int) -> Int: return x+1
def main():
    _ = piped(Optional(as_unary(increment))).ap(Optional(String("wrong")))
