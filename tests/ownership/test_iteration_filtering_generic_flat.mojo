"""Generic returned captured flat mapping retains current inner owners and releases abandoned state once."""
from fp.iteration import flat_map, filter, filter_map
from std.iter import iter, next
from std.memory import ArcPointer
from std.testing import assert_equal

from fp.iteration import FilterIterator, FilterMapIterator, FlatMapIterator
from std.iter import Iterator, IterableOwned

def selected[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](
    var function: F, var source: I
) -> FilterIterator[T, I, F] where I.Element == T:
    return filter(function^, source^)

def selected_again[T: Movable & Deinitable, I: Iterator, //, F: def(T) -> Bool](
    var function: F, var source: I
) -> FilterIterator[T, I, F] where I.Element == T:
    return selected(function^, source^)

def present[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //, F: def(var T) -> Optional[U]](
    var function: F, var source: I
) -> FilterMapIterator[T, U, I, F] where I.Element == T:
    return filter_map(function^, source^)

def present_again[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //, F: def(var T) -> Optional[U]](
    var function: F, var source: I
) -> FilterMapIterator[T, U, I, F] where I.Element == T:
    return present(function^, source^)

def expanded[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //, F: def(var T) -> U](
    var function: F, var source: I
) -> FlatMapIterator[T, U, I, F] where I.Element == T:
    return flat_map(function^, source^)

def expanded_again[T: Movable & Deinitable, U: Movable & Deinitable, I: Iterator, //, F: def(var T) -> U](
    var function: F, var source: I
) -> FlatMapIterator[T, U, I, F] where I.Element == T:
    return expanded(function^, source^)

@fieldwise_init
struct Counts(Copyable):
    var parents: ArcPointer[Int]
    var children: ArcPointer[Int]
    var created: ArcPointer[Int]
    var calls: ArcPointer[Int]
    var inners: ArcPointer[Int]
    var acquired: ArcPointer[Int]
    var copies: ArcPointer[Int]
    var captures: ArcPointer[Int]
    var pulls: ArcPointer[Int]

@fieldwise_init
struct Capture(Copyable):
    var offset: Int
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.offset = copy.offset
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct IterationFilteringGenericFlatToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Inner(Iterator):
    comptime Element = IterationFilteringGenericFlatToken
    var owner: OwnedInner
    def __next__(mut self) raises StopIteration -> IterationFilteringGenericFlatToken:
        if not self.owner.children: raise StopIteration()
        return self.owner.children.pop()
    def __deinit__(deinit self): self.owner.counts.inners[] += 1

@fieldwise_init
struct OwnedInner(IterableOwned):
    comptime IteratorOwnedType = Inner
    var parent: IterationFilteringGenericFlatToken
    var children: List[IterationFilteringGenericFlatToken]
    var counts: Counts
    def __iter__(var self) -> Inner:
        self.counts.acquired[] += 1
        return Inner(self^)

@fieldwise_init
struct Outer(Iterator):
    comptime Element = IterationFilteringGenericFlatToken
    var values: List[IterationFilteringGenericFlatToken]
    var pulls: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> IterationFilteringGenericFlatToken:
        self.pulls[] += 1
        if not self.values: raise StopIteration()
        return self.values.pop()

def exercise(library: Bool, length: Int, count: Int, counts: Counts) raises -> List[Int]:
    var state = Capture(1000, counts.copies, counts.captures)
    def expand(var parent: IterationFilteringGenericFlatToken) {var state^, counts} -> OwnedInner:
        counts.calls[] += 1
        var children = List[IterationFilteringGenericFlatToken]()
        for i in range(parent.value % 3):
            children.append(IterationFilteringGenericFlatToken(state.offset + parent.value * 10 + parent.value % 3 - i - 1, counts.children))
            counts.created[] += 1
        return OwnedInner(parent^, children^, counts.copy())
    var parents = List[IterationFilteringGenericFlatToken]()
    for i in range(length): parents.append(IterationFilteringGenericFlatToken(length - i - 1, counts.parents))
    var source = Outer(parents^, counts.pulls)
    var output = List[Int]()
    if library:
        var flattened = expanded_again(expand^, source^)
        assert_equal(counts.calls[], 0)
        assert_equal(counts.acquired[], 0)
        assert_equal(counts.pulls[], 0)
        assert_equal(counts.copies[], 0)
        for _ in range(count):
            var value = next(flattened)
            output.append(value.value)
    else:
        while len(output) < count:
            var inner = iter(expand(next(source)))
            while len(output) < count:
                var value: IterationFilteringGenericFlatToken
                try: value = next(inner)
                except: break
                output.append(value.value)
    return output^

def main() raises:
    for length in range(7):
        var total = 0
        for i in range(length): total += i % 3
        for count in range(total + 1):
            var expected = List[Int]()
            var required = 0
            var allocated = 0
            for i in range(length):
                if len(expected) == count: break
                required += 1
                allocated += i % 3
                for j in range(i % 3):
                    if len(expected) < count: expected.append(1000 + i * 10 + j)
            for library in range(2):
                var counts = Counts(ArcPointer(0), ArcPointer(0), ArcPointer(0),
                                    ArcPointer(0), ArcPointer(0), ArcPointer(0),
                                    ArcPointer(0), ArcPointer(0), ArcPointer(0))
                assert_equal(exercise(Bool(library), length, count, counts), expected)
                assert_equal(counts.parents[], length)
                assert_equal(counts.children[], allocated)
                assert_equal(counts.created[], allocated)
                assert_equal(counts.calls[], required)
                assert_equal(counts.inners[], required)
                assert_equal(counts.acquired[], required)
                assert_equal(counts.pulls[], required)
                assert_equal(counts.copies[], 0)
                assert_equal(counts.captures[], 1)
