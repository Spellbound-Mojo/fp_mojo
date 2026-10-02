# error: scan_left: source element type must match T
"""Same-layout source elements must not pass a nominal adapter refinement."""
from fp.iteration import ScanIterator
from std.iter import iter, next

@fieldwise_init
struct First(Copyable):
    var value: Int

@fieldwise_init
struct Second(Copyable):
    var value: Int

def convert(var acc: Int, var value: First) -> Int: return acc + value.value

def main() raises:
    comptime assert First != Second
    var values = List[Second]()
    values.append(Second(1))
    var source = iter(values^)
    var adapter = ScanIterator[Int, First, type_of(source)](convert, 0, source^, False, False)
    _ = next(adapter)
