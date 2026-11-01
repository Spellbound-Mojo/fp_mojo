# error: cannot call function that may raise
from fp.callables import as_unary

def checked(var value: Int) raises Int -> Int:
    if value < 0: raise value
    return value

def main():
    var pointer: def(var Int) raises Int thin -> Int = checked
    var callback = as_unary(pointer)
    _ = callback(-1)
