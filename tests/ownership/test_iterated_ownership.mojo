"""Consuming chains transfer move-only payloads and clean up every exit path."""
from fp.iteration import iterated
from std.iter import enumerate, next
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct IteratedToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct IteratedOwnedFailure(Movable, Writable):
    var value: Int

def increment(var value: IteratedToken) -> IteratedToken:
    value.value += 1
    return value^

def keep(value: IteratedToken) -> Bool:
    return value.value % 2 == 0

def present(var value: IteratedToken) -> Optional[IteratedToken]:
    return Optional(value^)

def expand(var value: IteratedToken) -> List[IteratedToken]:
    var result = List[IteratedToken]()
    result.append(value^)
    return result^

def fail(var total: IteratedToken, var value: IteratedToken) raises IteratedOwnedFailure -> IteratedToken:
    raise IteratedOwnedFailure(value.value)

def main() raises:
    for mode in range(2):
        var drops = ArcPointer(0)
        var tokens: List[IteratedToken] = [IteratedToken(1, drops), IteratedToken(2, drops), IteratedToken(3, drops)]
        var stream = iterated(tokens^).map(increment).filter(keep).filter_map(present).flat_map(expand)
        assert_equal(drops[], 0)
        var values: List[IteratedToken]
        if mode:
            values = stream^.collect_list()
        else:
            values = stream^.to_list()
        assert_equal(len(values), 2)
        assert_equal(values[0].value, 2)
        assert_equal(values[1].value, 4)
        assert_equal(drops[], 1)
        values.clear()
        assert_equal(drops[], 3)

    var drops = ArcPointer(0)
    var tokens: List[IteratedToken] = [IteratedToken(4, drops), IteratedToken(5, drops)]
    var numbered = enumerate(iterated(tokens^))
    var first = next(numbered)
    assert_equal(first[0], 0)
    assert_equal(first[1].value, 4)
    _ = first^
    _ = numbered^
    assert_equal(drops[], 2)

    var calls = 0
    var capture = IteratedToken(100, drops)
    def owned(var value: Int) {var capture^, mut calls} -> Int:
        calls += 1
        return value + capture.value
    var abandoned = iterated(range(3)).map(owned^)
    assert_equal(next(abandoned), 100)
    _ = abandoned^
    assert_equal(calls, 1)
    assert_equal(drops[], 3)

    var failing: List[IteratedToken] = [IteratedToken(7, drops), IteratedToken(8, drops)]
    var caught = False
    try:
        _ = iterated(failing^).fold_left(fail, IteratedToken(0, drops))
    except error:
        comptime assert type_of(error) == IteratedOwnedFailure
        assert_equal(error.value, 7)
        caught = True
    assert_equal(caught, True)
    assert_equal(drops[], 6)

    var searched: List[IteratedToken] = [IteratedToken(10, drops), IteratedToken(11, drops)]
    var found = iterated(searched^).find(keep)
    assert_equal(found.value().value, 10)
    assert_equal(drops[], 7)
    _ = found^
    assert_equal(drops[], 8)
