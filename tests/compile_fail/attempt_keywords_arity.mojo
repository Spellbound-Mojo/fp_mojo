# error: no matching function in call to 'attempt_kwargs'
from fp.data import attempt_kwargs

def target(first: Int, second: Int, third: Int, /, var **values: Int) -> Int:
    return len(values)

def main():
    _ = attempt_kwargs(target, 1, 2, 3, one=7)
