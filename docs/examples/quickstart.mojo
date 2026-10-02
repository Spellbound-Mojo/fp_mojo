"""The smallest complete FP Mojo program."""
from fp.functions import identity, pipe
from std.testing import assert_equal

def twice(var value: Int) -> Int:
    return value * 2

def main() raises:
    var answer = pipe(21, twice)
    assert_equal(answer, 42)
    print(answer)
