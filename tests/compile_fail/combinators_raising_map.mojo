# error: no matching method in call to 'map'
from fp.iteration import iterated

def checked(value: Int) raises -> Int:
    if value == 2: raise Error("stop")
    return value

def main() raises:
    _ = iterated(range(3)).map(checked)
