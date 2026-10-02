# error: map: source element type must match T
"""Same-layout source elements must not pass a nominal adapter refinement."""
from fp.iteration import MapIterator
from std.iter import iter, next

@fieldwise_init
struct First(Copyable):
    var value: Int

@fieldwise_init
struct Second(Copyable):
    var value: Int

def convert(var value: First) -> Int: return value.value

def main() raises:
    comptime assert First != Second
    var values = List[Second]()
    values.append(Second(1))
    var source = iter(values^)
    var adapter = MapIterator[First, Int, type_of(source)](convert, source^, False)
    _ = next(adapter)
