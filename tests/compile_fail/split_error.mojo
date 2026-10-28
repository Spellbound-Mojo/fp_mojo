# error: constraint failed: flow: stage 1
# error: raises String
from fp.functions import split
def good(var value: Int) -> Int: return value+1
def main(): _ = split(left, right)
def left(var a: Int) raises Int -> Int: raise a
def right(var a: Int) raises String -> Int: raise String(a)
