# error: flow: stage 1 must take one argument
from fp.functions import flow, flip
def add(var left: Int, var right: Int) -> Int: return left + right
def main(): _ = flow(add, flip(add))
