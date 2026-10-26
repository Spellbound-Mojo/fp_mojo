# error: invalid call to '__call__'
from fp.callables import as_unary

def scalar(var value: Int) -> Int:
    return value + 1

def main():
    var pointer: def(var Int) thin -> Int = scalar
    var callback = as_unary(pointer)
    _ = callback(String("wrong type"))
