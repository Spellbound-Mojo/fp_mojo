# error: invalid call to 'ap': violated constraint
from fp.functions import pipeline
from fp.algebra import OptionalFamily
def increment(x: Int) -> Int: return x+1
def main():
    _ = pipeline[OptionalFamily](Optional(increment)).ap(Optional(1))
