from fp._argument_staged import Capture
from std.testing import assert_equal

def argument(mut log: Int, n: Int) -> Int:
    log = log * 10 + n
    return n

def main() raises:
    var state = 0
    var log = 0
    def callback(mut first: Int, var second: Int, /, var **options: Int) {mut log} -> Int:
        log = log * 10 + 4
        first += second
        for item in options.items(): first += item.value
        return first
    var pending = Capture[Never].kwargs(state, argument(log, 1), first=argument(log, 2), function=argument(log, 3))
    assert_equal(log, 123)
    assert_equal(state, 0)
    var result = pending^.run(callback)
    assert_equal(log, 1234)
    assert_equal(result._ok().value, 6)
    assert_equal(state, 6)
