# error: no matching function
from fp.functions import flow, Identity
def mutate(mut first: Int, second: Int) -> Int:
    first += second
    return first
def main(): _ = flow(mutate, Identity[Int]())
