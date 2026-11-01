# error: no matching function in call to 'pipe'
# Two-stage mixed calls are supported; longer mixed calls still promote natives.
from fp.functions import pipe, as_unary
def increment(var value: Int) -> Int: return value + 1
def label(var value: Int) -> String: return String(value)
def suffix(var value: String) -> String: return value + "!"
def main():
    var promoted = as_unary(increment)
    _ = pipe(1, promoted, label, suffix)
