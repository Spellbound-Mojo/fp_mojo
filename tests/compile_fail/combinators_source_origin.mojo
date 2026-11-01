# error: cannot implicitly convert
from fp.iteration import iterated
from std.iter import iter

def square(value: Int) -> Int: return value * value

def check(anchor: List[Int]):
    var local: List[Int] = [3, 4]
    var expected = iterated(iter(anchor)).map(square)
    var candidate = iterated(iter(local)).map(square)
    var invalid: type_of(expected) = candidate^
    _ = expected^
    _ = invalid^

def main():
    var anchor: List[Int] = [1, 2]
    check(anchor)
