# error: no matching function in call to 'as_binary'
from fp.callables import as_binary
def mutate(mut first: Int, second: Int) -> Int:
    first += second
    return first
def main(): _ = as_binary(mutate)
