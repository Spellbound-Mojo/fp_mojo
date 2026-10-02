"""Move-only payload transfer and cleanup when a lazy traversal is abandoned."""
from fp.iteration import map, filter, filter_map, flat_map, flatten, collect_list
from std.iter import iter, once, Iterator
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct IterationAdaptersToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def increment(var value: IterationAdaptersToken) -> IterationAdaptersToken:
    value.value += 1
    return value^

def even(value: IterationAdaptersToken) -> Bool:
    return value.value % 2 == 0

def optional(var value: IterationAdaptersToken) -> Optional[IterationAdaptersToken]:
    if even(value): return Optional(value^)
    return None

def nested(var value: IterationAdaptersToken) -> List[IterationAdaptersToken]:
    var result = List[IterationAdaptersToken]()
    result.append(value^)
    return result^

@fieldwise_init
struct Outer(Iterator):
    comptime Element = List[IterationAdaptersToken]
    var source: List[List[IterationAdaptersToken]]
    var pulls: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> Self.Element:
        self.pulls[] += 1
        if not self.source: raise StopIteration()
        return self.source.pop()

def abandon(mode: Int, drops: ArcPointer[Int]) raises:
    var values: List[IterationAdaptersToken] = [IterationAdaptersToken(1, drops), IterationAdaptersToken(2, drops), IterationAdaptersToken(3, drops)]
    if mode == 0:
        var output = map(increment, iter(values^))
        var first = output.__next__()
        assert_equal(first.value, 2)
        assert_equal(drops[], 0)
        _ = first^
        _ = output^
    elif mode == 1:
        var output = filter(even, iter(values^))
        var first = output.__next__()
        assert_equal(first.value, 2)
        assert_equal(drops[], 1)
        _ = first^
        _ = output^
    elif mode == 2:
        var output = filter_map(optional, iter(values^))
        var first = output.__next__()
        assert_equal(first.value, 2)
        assert_equal(drops[], 1)
        _ = first^
        _ = output^
    else:
        var output = flat_map(nested, iter(values^))
        var first = output.__next__()
        assert_equal(first.value, 1)
        assert_equal(drops[], 0)
        _ = first^
        _ = output^

def abandon_flatten(drops: ArcPointer[Int], pulls: ArcPointer[Int]) raises:
    var tail: List[IterationAdaptersToken] = [IterationAdaptersToken(3, drops)]
    var head: List[IterationAdaptersToken] = [IterationAdaptersToken(1, drops), IterationAdaptersToken(2, drops)]
    var values: List[List[IterationAdaptersToken]] = [tail^, head^]
    var output = flatten(Outer(values^, pulls))
    assert_equal(pulls[], 0)
    var first = output.__next__()
    assert_equal(first.value, 1)
    assert_equal(pulls[], 1)
    assert_equal(drops[], 0)
    _ = first^
    _ = output^

def main() raises:
    for mode in range(4):
        var drops = ArcPointer(0)
        abandon(mode, drops)
        assert_equal(drops[], 3)
    var drops = ArcPointer(0)
    var pulls = ArcPointer(0)
    abandon_flatten(drops, pulls)
    assert_equal(drops[], 3)
    assert_equal(pulls[], 1)
    var values: List[IterationAdaptersToken] = [IterationAdaptersToken(1, drops), IterationAdaptersToken(2, drops)]
    var collected = collect_list(map(increment, iter(values^)))
    assert_equal(drops[], 3)
    assert_equal(collected[0].value, 2)
    assert_equal(collected[1].value, 3)
    collected.clear()
    assert_equal(drops[], 5)
    # A native Iterator can itself be an inner sequence; no new ownership model.
    var inner = once(IterationAdaptersToken(8, drops))
    var flattened = collect_list(flatten(once(inner^)))
    assert_equal(flattened[0].value, 8)
    flattened.clear()
    assert_equal(drops[], 6)
