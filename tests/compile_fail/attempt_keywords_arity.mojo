# error: no matching function in call to 'attempt'
from fp.data import attempt

def target(first: Int, second: Int, third: Int, /, var **values: Int) -> Int:
    return len(values)

def main():
    _ = attempt(target, 1, 2, 3, one=7)
