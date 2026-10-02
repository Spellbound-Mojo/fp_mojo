# error: filter: source element type must match T
"""Explicit generic aliases cannot turn same-layout elements into another type."""
from fp.iteration import FilterIterator
from std.iter import iter, next

@fieldwise_init
struct First(Copyable):
    var value: Int

@fieldwise_init
struct Second(Copyable):
    var value: Int

def callback(value: First) -> Bool: return value.value > 0

def main() raises:
    comptime assert First != Second
    var values = List[Second]()
    values.append(Second(1))
    var source = iter(values^)
    var adapter = FilterIterator[First, type_of(source)](callback, source^, False)
    _ = next(adapter)
