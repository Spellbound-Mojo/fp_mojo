# error: no matching function in call to 'attempt_kwargs'
from fp.data import attempt_kwargs

def update(mut value: Int, /, var **extra: Int) raises String -> Int:
    value += len(extra)
    if value < 0:
        raise String("negative")
    return value

def main():
    var value = 7
    _ = attempt_kwargs[mutable=False](update, value, extra=1)
