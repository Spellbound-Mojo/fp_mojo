# error: use of uninitialized value 'callback'
from fp.functions import tupled
def add(first: Int, second: Int) -> Int: return first + second
def main():
    var callback = tupled(add)
    _ = callback^.call_once((1, 2))
    _ = callback((3, 4))
