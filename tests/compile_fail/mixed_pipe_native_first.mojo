# error: no matching function
from fp.functions import pipe, Identity
def mutate(mut value: Int) -> Int:
    value += 1
    return value
def main(): _ = pipe(3, mutate, Identity[Int]())
