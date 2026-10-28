# error: flow: stage 1 must take one argument
from fp.functions import flow, Identity
def add(var first: Int, var second: Int) -> Int: return first + second
def plus(var value: Int) -> Int: return value + 1
def main(): _ = flow(add, Identity[Int]()).compose(plus)
