# error: no matching function in call to 'attempt'
from fp.data import attempt

def value() -> Int:
    return 7

def main():
    _ = attempt[zero=False](value)
