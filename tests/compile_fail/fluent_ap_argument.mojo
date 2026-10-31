# error: constraint
from fp.functions import pipeline
from fp.callables import as_unary
def increment(x: Int) -> Int: return x+1
def main():
    _ = pipeline(Optional(as_unary(increment))).ap(Optional(String("wrong")))
