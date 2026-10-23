# error: violated constraint
from fp.iteration import iterated
def callback(var value: Int) -> Int: return value
def main(): _ = iterated(range(2)).align_with(range(3), callback)
