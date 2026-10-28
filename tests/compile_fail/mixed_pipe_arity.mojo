# error: no matching function
from fp.functions import pipe, Identity
def binary(var left: Int, var right: Int) -> Int: return left + right
def main(): _ = pipe(3, binary, Identity[Int]())
