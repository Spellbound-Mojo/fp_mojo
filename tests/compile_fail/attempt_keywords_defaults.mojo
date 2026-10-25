# error: no matching function in call to 'attempt_kwargs'
from fp.data import attempt_kwargs

def target(first: Int = 3, /, var **values: Int) -> Int:
    return len(values)

def main():
    _ = attempt_kwargs[owned=True](target, one=7)
