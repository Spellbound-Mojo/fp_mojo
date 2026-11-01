# error: constraint failed: flow: stage
# error: raises String
from fp.functions import merge
def good(var value: Int) -> Int: return value+1
def main(): _ = merge(left, right)
def left(var a: Int) raises Int -> Int: raise a
def right(var a: Int) raises String -> Int: raise String(a)
