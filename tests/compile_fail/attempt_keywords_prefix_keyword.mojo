# error: no matching method in call to 'run'
from fp.data import Capture

def target(first: Int, /, var **values: Int) -> Int:
    return len(values)

def main():
    _ = Capture.kwargs(first=3, one=7).run(target)
