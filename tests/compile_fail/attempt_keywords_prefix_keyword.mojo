# error: no matching function in call to 'attempt_kwargs'
from fp.data import attempt_kwargs

def target(first: Int, /, var **values: Int) -> Int:
    return len(values)

def main():
    _ = attempt_kwargs(target, first=3, one=7)
