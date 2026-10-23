# error: constraint
from fp.functions import piped
def increment(x: Int) -> Int: return x+1
def main():
    _ = piped(Optional(increment)).ap(Optional(1))
