# error: no matching
from fp.effects import State, inspect
def read(var value: String) -> Int: return value.byte_length()
def main():
    var pointer: def(var String) thin -> Int = read
    _ = inspect[State[String]](pointer)
