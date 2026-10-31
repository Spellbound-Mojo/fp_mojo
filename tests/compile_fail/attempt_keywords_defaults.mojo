# error: no matching method in call to 'run'
from fp.data import Capture

def target(first: Int = 3, /, var **values: Int) -> Int:
    return len(values)

def main():
    _ = Capture.kwargs(one=7).run(target)
