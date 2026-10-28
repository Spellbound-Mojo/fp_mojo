# error: no matching function
from fp.functions import compose, Identity
def mutate(mut value: Int) -> Int:
    value += 1
    return value
def main(): _ = compose(mutate, Identity[Int]())
