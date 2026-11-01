# error: no matching method
from fp.functions import flow, Identity
def mutate(mut value: Int) -> Int:
    value += 1
    return value
def main(): _ = flow(Identity[Int](), Identity[Int]()).compose(mutate)
