# error: no matching function in call to 'pipe'
from fp.functions import pipe, as_unary
def increment(var value: Int) -> Int: return value + 1
def label(var value: Int) -> String: return String(value)
def main():
    var promoted = as_unary(increment)
    _ = pipe(1, promoted, label)
