# error: use of uninitialized value 'callback'
from fp.functions import split
def increment(value: Int) -> Int: return value + 1
def main():
    var callback = split(increment, increment)
    _ = callback^.call_once((1, 2))
    _ = callback((2, 2))
