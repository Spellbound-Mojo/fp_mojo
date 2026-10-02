"""Identity and associativity for pure terminating heterogeneous pipelines."""
from fp.functions import pipe, as_unary
from std.testing import assert_equal

def identity(var value: Int) -> Int: return value
def increment(var value: Int) -> Int: return value + 1
def label(var value: Int) -> String: return "v=" + String(value)
def size(value: String) -> Int: return value.byte_length()
def increment_label(var value: Int) -> String: return label(increment(value))
def label_size(var value: Int) -> Int: return size(label(value))

def main() raises:
    var same = as_unary(identity)
    var add = as_unary(increment)
    var text = as_unary(label)
    var length = as_unary(size)
    var left = as_unary(increment_label)
    var right = as_unary(label_size)
    for value in range(-40, 41):
        assert_equal(pipe(value, same, add), increment(value))
        assert_equal(pipe(value, add, same), increment(value))
        var result = pipe(value, add, text, length)
        assert_equal(result, size(label(increment(value))))
        assert_equal(result, pipe(value, left, length))
        assert_equal(result, pipe(value, add, right))
