# error: no matching method in call to 'map'
from fp.iteration import iterated

def fail(var value: Int) raises -> Int:
    raise Error("callback failure")

def main():
    _ = iterated(range(3)).map(fail)
