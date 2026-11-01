# error: use of uninitialized value 'callback'
from fp.functions import merge
def increment(value: Int) -> Int: return value + 1
def main():
    var callback = merge(increment, increment)
    _ = callback^.call_once(1)
    _ = callback(2)
