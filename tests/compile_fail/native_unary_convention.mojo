# error: no matching function in call to 'as_unary'
from fp.callables import as_unary

def mutate(mut value: Int) -> Int:
    value += 1
    return value

def main():
    var pointer: def(mut Int) thin -> Int = mutate
    _ = as_unary(pointer)
