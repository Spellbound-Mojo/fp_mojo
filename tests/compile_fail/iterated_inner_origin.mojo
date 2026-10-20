# error: cannot implicitly convert
from fp.iteration import iterated
from std.iter import iter, once

def check(anchor: List[Int], other: List[Int]):
    var expected = iterated(once(iter(anchor))).flatten()
    var candidate = iterated(once(iter(other))).flatten()
    var invalid: type_of(expected) = candidate^
    _ = expected^
    _ = invalid^

def main():
    var anchor: List[Int] = [1, 2]
    var other: List[Int] = [3, 4]
    check(anchor, other)
