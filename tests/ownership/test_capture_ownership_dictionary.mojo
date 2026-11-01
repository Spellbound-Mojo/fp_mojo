from fp.data import Capture
from std.collections import StringDict
from std.testing import assert_equal

def callback(mut state: Int, var text: String, /, var **options: Int) -> Int:
    state += text.byte_length()
    for item in options.items(): state += item.value
    return state

def main() raises:
    var state = 0
    var empty = StringDict[Int]()
    var pending = Capture[Never].mutable(state).take("a").kwargs(**empty^)
    assert_equal(pending^.run(callback)._ok().value, 1)
    var options = StringDict[Int]()
    options["extra"] = 2
    options["bonus"] = 3
    assert_equal(Capture[Never].mutable(state).take("a").kwargs(**options^).run(callback)._ok().value, 7)
    assert_equal(state, 7)
