# error: keyword argument 'one' was already used
from fp.data import attempt

def target(var **values: Int) -> Int:
    return len(values)

def main():
    _ = attempt(target, one=3, one=7)
