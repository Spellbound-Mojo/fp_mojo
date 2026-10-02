"""Copy-counted independent snapshots and no initial source pull."""
from fp.iteration import scan_left, collect_list
from std.iter import Iterator, iter
from std.memory import ArcPointer
from observations import Counter, count
from std.testing import assert_equal

struct Snapshot(Copyable):
    var values: List[Int]
    var copies: Counter
    var drops: Counter
    def __init__(out self, copies: Counter, drops: Counter):
        self.values = List[Int]()
        self.copies = copies
        self.drops = drops
    def __init__(out self, *, copy: Self):
        count(copy.copies)
        self.values = copy.values.copy()
        self.copies = copy.copies
        self.drops = copy.drops
    def __deinit__(deinit self):
        count(self.drops)

@fieldwise_init
struct Input(Movable):
    var value: Int
    var calls: Counter

@fieldwise_init
struct Source(Iterator):
    comptime Element = Input
    var index: Int
    var length: Int
    var pulls: Counter
    var calls: Counter
    def __next__(mut self) raises StopIteration -> Input:
        count(self.pulls)
        if self.index == self.length: raise StopIteration()
        self.index += 1
        return Input(self.index, self.calls)

def step(var state: Snapshot, var value: Input) -> Snapshot:
    count(value.calls)
    state.values.append(value.value)
    return state^

def exercise(length: Int, take_count: Int, copies: Counter, drops: Counter) raises:
    var pulls = ArcPointer(0)
    var calls = ArcPointer(0)
    var scanned = scan_left(step, Snapshot(copies, drops), Source(0, length, pulls, calls))
    assert_equal(pulls[], 0)
    assert_equal(copies[], 0)
    assert_equal(calls[], 0)
    var retained = List[Snapshot]()
    for i in range(take_count):
        retained.append(scanned.__next__())
        assert_equal(pulls[], i)
        assert_equal(calls[], i)
        assert_equal(copies[], i + 1)
    if take_count:
        retained[0].values.append(99)
        for i in range(1, take_count):
            assert_equal(len(retained[i].values), i)
            assert_equal(retained[i].values[i - 1], i)
    if take_count == length + 1:
        for _ in range(2):
            var stopped = False
            try: _ = scanned.__next__()
            except: stopped = True
            assert_equal(stopped, True)
        assert_equal(pulls[], length + 1)
        assert_equal(calls[], length)
        assert_equal(copies[], length + 1)

def append(var acc: String, var value: Int) -> String:
    acc += String(value)
    return acc^

def main() raises:
    for length in range(5):
        for take_count in range(length + 2):
            var copies = ArcPointer(0)
            var drops = ArcPointer(0)
            exercise(length, take_count, copies, drops)
            assert_equal(copies[], take_count)
            assert_equal(drops[], take_count + 1)
    var states = collect_list(scan_left(append, String("s"), iter(range(3))))
    var expected: List[String] = ["s", "s0", "s01", "s012"]
    assert_equal(states, expected)
