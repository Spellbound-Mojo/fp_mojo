"""Generic scan return preserves initial-first, independent snapshots and cleanup."""
from fp.iteration import ScanIterator, scan_left
from std.iter import Iterator, next
from std.memory import ArcPointer
from std.testing import assert_equal

def scanned[A: Copyable & Deinitable, T: Movable & Deinitable, I: Iterator, //,
            F: def(var A, var T) -> A](var function: F, var initial: A, var source: I) -> ScanIterator[A, T, I, F] where I.Element == T:
    return scan_left(function^, initial^, source^)


@fieldwise_init
struct Snapshot(Copyable):
    var values: List[Int]
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.values = copy.values.copy()
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct State(Movable):
    var offset: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1

@fieldwise_init
struct Source(Iterator):
    comptime Element = Int
    var index: Int
    var length: Int
    var pulls: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[] += 1
        if self.index == self.length: raise StopIteration()
        self.index += 1
        return self.index

def exercise(library: Bool, length: Int, count: Int, copies: ArcPointer[Int],
             drops: ArcPointer[Int], state_drops: ArcPointer[Int]) raises:
    var pulls = ArcPointer(0)
    var calls = 0
    var state = State(10, state_drops)
    def step(var snapshot: Snapshot, var value: Int) {var state^, mut calls} -> Snapshot:
        calls += 1
        snapshot.values.append(value + state.offset + calls)
        return snapshot^
    var accumulator = Snapshot(List[Int](), copies, drops)
    var source = Source(0, length, pulls)
    var snapshots = List[Snapshot]()
    if library:
        var adapter = scanned(step^, accumulator^, source^)
        assert_equal(copies[], 0)
        assert_equal(calls, 0)
        assert_equal(pulls[], 0)
        for i in range(count):
            snapshots.append(next(adapter))
            assert_equal(calls, i)
            assert_equal(pulls[], i)
            assert_equal(copies[], i + 1)
        if count == length + 1:
            for _ in range(2):
                var exhausted = False
                try: _ = next(adapter)
                except: exhausted = True
                assert_equal(exhausted, True)
            assert_equal(pulls[], length + 1)
    else:
        if count: snapshots.append(accumulator.copy())
        for _ in range(1, count):
            accumulator = step(accumulator^, next(source))
            snapshots.append(accumulator.copy())
        if count == length + 1:
            var exhausted = False
            try: _ = next(source)
            except: exhausted = True
            assert_equal(exhausted, True)
            assert_equal(pulls[], length + 1)
    assert_equal(copies[], count)
    assert_equal(calls, max(count - 1, 0))
    for i in range(count):
        var expected = List[Int]()
        for j in range(1, i + 1): expected.append(10 + 2 * j)
        assert_equal(snapshots[i].values, expected)
    if count:
        snapshots[0].values.append(99)
        for i in range(1, count): assert_equal(len(snapshots[i].values), i)

def main() raises:
    for length in range(5):
        for count in range(length + 2):
            for library in range(2):
                var copies = ArcPointer(0)
                var drops = ArcPointer(0)
                var state_drops = ArcPointer(0)
                exercise(Bool(library), length, count, copies, drops, state_drops)
                assert_equal(copies[], count)
                assert_equal(drops[], count + 1)
                assert_equal(state_drops[], 1)
