# error: cannot implicitly convert
from fp.iteration import iterated
from std.iter import iter

def check(anchor: List[Int]):
    var local: List[Int] = [3, 4]
    var expected = iterated(iter(anchor))
    var candidate = iterated(iter(local))
    var invalid: type_of(expected) = candidate^
    _ = expected^
    _ = invalid^

def main():
    var anchor: List[Int] = [1, 2]
    check(anchor)
