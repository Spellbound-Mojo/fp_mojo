# error: flow: stage 2 must take one argument
from fp.functions import flow, Identity, flip
def add(var first: Int, var second: Int) -> Int: return first + second
def main(): _ = flow(Identity[Int](), Identity[Int]()).then(flip(add))
