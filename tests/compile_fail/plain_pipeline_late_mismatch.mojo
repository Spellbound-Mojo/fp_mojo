# error: pipe: stage 5 should take String, return Int and raise nothing
# error: it takes Int, returns Int
from fp.functions import pipe

def inc(value: Int) -> Int:
    return value + 1

def label(value: Int) -> String:
    return String(value)

def main():
    # The mismatch is the sixth function: it takes Int after label returned String.
    _ = pipe(1, inc, inc, inc, inc, label, inc, inc, inc)
