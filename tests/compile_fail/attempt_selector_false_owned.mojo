# error: no matching function in call to 'attempt'
from fp.data import attempt

def take(var value: String) -> Int:
    return value.byte_length()

def main():
    _ = attempt[owned=False](take, String("Mojo"))
