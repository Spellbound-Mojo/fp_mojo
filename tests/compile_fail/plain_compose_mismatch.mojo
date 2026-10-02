# error: compose: stage 1 (argument 0) should take String, return Int and raise nothing
# error: it takes Int, returns Int
from fp.functions import compose

def inc(value: Int) -> Int:
    return value + 1

def label(value: Int) -> String:
    return String(value)

def main():
    # compose runs label first; inc, its first argument, then receives a String.
    var chain = compose(inc, label)
    _ = chain^
