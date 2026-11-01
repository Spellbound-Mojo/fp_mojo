# error: no matching method in call to 'run'
from fp.data import Capture

def target(var **values: Int) -> Int:
    return len(values)

def main():
    _ = Capture.kwargs(one=String("wrong")).run(target)
