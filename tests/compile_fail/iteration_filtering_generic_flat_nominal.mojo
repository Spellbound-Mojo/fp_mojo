# error: map: source element type must match T
"""FlatMapIterator retains MapIterator's nominal source protection."""
from fp.iteration import MapIterator, FilterIterator, FilterMapIterator, FlatMapIterator, filter, filter_map, flat_map, collect_list
from std.iter import Iterator, IterableOwned, iter, next
from std.testing import assert_equal

@fieldwise_init
struct First(Copyable):
    var value: Int

@fieldwise_init
struct Second(Copyable):
    var value: Int

def expand(var value: First) -> List[Int]: return [value.value]

def main() raises:
    comptime assert First != Second
    var values = List[Second]()
    values.append(Second(1))
    var source = iter(values^)
    var mapped = MapIterator[First, List[Int], type_of(source)](expand, source^, False)
    var adapter = FlatMapIterator[First, List[Int], type_of(source)](mapped^, None, False)
    _ = next(adapter)
