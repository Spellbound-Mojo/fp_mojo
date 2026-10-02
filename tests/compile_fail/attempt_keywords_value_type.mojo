# error: no matching function in call to 'attempt'
from fp.data import attempt

def target(var **values: Int) -> Int:
    return len(values)

def main():
    _ = attempt(target, one=String("wrong"))
