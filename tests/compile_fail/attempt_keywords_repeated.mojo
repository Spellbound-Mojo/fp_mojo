# error: keyword argument 'one' was already used
from fp.data import Capture

def target(var **values: Int) -> Int:
    return len(values)

def main():
    _ = Capture.kwargs(one=3, one=7).run(target)
