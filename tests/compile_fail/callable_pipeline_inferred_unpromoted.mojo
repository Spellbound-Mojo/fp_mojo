# error: pipe: stage 1 must take one argument: a Unary value, or a native function promoted with as_unary
from fp.functions import pipe, as_unary
def increment(var value: Int) -> Int: return value + 1
def label(var value: Int) -> String: return String(value)
def main():
    var promoted = as_unary(increment)
    _ = pipe(1, promoted, label)
