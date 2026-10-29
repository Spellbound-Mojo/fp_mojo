# error: no matching
from fp.iteration import iterated
def callback(var value: Int) -> Int: return value
def main():
    var pointer: def(var Int) thin -> Int = callback
    _ = iterated(range(2)).traverse_void(pointer)
