# error: cannot call function that may raise in a context that cannot raise
from fp.functions import pipe, as_unary
def fail(var value: Int) raises Int -> Int: raise value
def increment(var value: Int) -> Int: return value + 1
def main():
    var a = as_unary(fail)
    var b = as_unary(increment)
    _ = pipe(1, a, b)
