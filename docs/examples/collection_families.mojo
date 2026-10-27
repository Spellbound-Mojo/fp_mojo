"""Select element mapping explicitly for fixed and variable length sequences."""
from std.collections import Array, Deque
from std.testing import assert_equal
from fp.functions import pipeline

def text(var value: Int) -> String: return String(value)
def bytes(var value: String) -> Int: return value.byte_length()
def positive(value: Int) -> Bool: return value > 0

def main() raises:
    var values: Array[Int, 2] = [7, 42]
    var lengths = pipeline(values^).elements().map(text).map(bytes).get()
    comptime assert type_of(lengths) == Array[Int, 2]
    assert_equal(lengths[0], 1)
    assert_equal(lengths[1], 2)
    print("array lengths:", lengths[0], lengths[1])

    var queue = Deque[Int]()
    queue.append(-1)
    queue.append(42)
    var labels = pipeline(queue^).elements().filter(positive).map(text).get()
    var label = labels.pop()
    assert_equal(label, "42")
    print("queue label:", label)
