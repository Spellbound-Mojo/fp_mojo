"""Every node payload and every match result is destroyed exactly once."""
import fp
from fp.adt import Data, Cases, Node, Value
from fp.matching import Next
from std.memory import ArcPointer
from std.testing import assert_equal


struct CleanupTally(Copyable):
    """Counts the values made and destroyed."""

    var made: ArcPointer[Int]
    var destroyed: ArcPointer[Int]

    def __init__(out self):
        self.made = ArcPointer(0)
        self.destroyed = ArcPointer(0)

    def live(self) -> Int:
        return self.made[] - self.destroyed[]


struct CleanupPayload(Movable):
    """A node payload that cannot be copied."""

    var tally: CleanupTally

    def __init__(out self, tally: CleanupTally):
        self.tally = tally.copy()
        self.tally.made[] += 1

    def __init__(out self, *, deinit take: Self):
        self.tally = take.tally^

    def __deinit__(deinit self):
        self.tally.destroyed[] += 1


struct CleanupResult(Copyable):
    """A match result whose copies are counted too."""

    var value: Int
    var tally: CleanupTally

    def __init__(out self, value: Int, tally: CleanupTally):
        self.value = value
        self.tally = tally.copy()
        self.tally.made[] += 1

    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.tally = copy.tally.copy()
        self.tally.made[] += 1

    def __init__(out self, *, deinit take: Self):
        self.value = take.value
        self.tally = take.tally^

    def __deinit__(deinit self):
        self.tally.destroyed[] += 1


@fieldwise_init
struct CleanupLeaf(Copyable):
    var value: Int


@fieldwise_init
struct CleanupHeld(Movable):
    var payload: CleanupPayload


@fieldwise_init
struct CleanupAdd[R: Value](Movable):
    var left: Self.R
    var right: Self.R


@fieldwise_init
struct CleanupPick[R: Value](Movable):
    var first: Self.R
    var second: Self.R


struct CleanupExpr(Data):
    comptime Layer[R: Value] = Cases[CleanupLeaf, CleanupHeld, CleanupAdd[R], CleanupPick[R]]


comptime C = Node[CleanupExpr]


@fieldwise_init
struct CleanupStop(Movable):
    var at: Int


def leaf(l: CleanupLeaf, tally: CleanupTally) raises CleanupStop -> CleanupResult:
    if l.value < 0:
        raise CleanupStop(l.value)
    return CleanupResult(l.value, tally)


def held(h: CleanupHeld, tally: CleanupTally) raises CleanupStop -> CleanupResult:
    return CleanupResult(0, tally)


def big(a: CleanupAdd[CleanupResult], tally: CleanupTally) raises CleanupStop -> Bool:
    return a.left.value > 100


def capped(a: CleanupAdd[CleanupResult], tally: CleanupTally) raises CleanupStop -> CleanupResult:
    return CleanupResult(100, tally)


def add(a: CleanupAdd[CleanupResult], tally: CleanupTally) raises CleanupStop -> CleanupResult:
    return CleanupResult(a.left.value + a.right.value, tally)


def pick(p: CleanupPick[C], tally: CleanupTally) raises CleanupStop -> Next[C]:
    return Next(p.second)


def run(x: C, tally: CleanupTally) -> Int:
    try:
        var result = fp.match(x, fp.when[big, capped], add, leaf, held, pick, context=tally)
        return result.value
    except error:
        return -1000 + error.at


def main() raises:
    var payloads = CleanupTally()
    var results = CleanupTally()
    var one: C = CleanupLeaf(1)

    # Releasing nodes destroys each payload once, shared or a million deep.
    var item: C = CleanupHeld(CleanupPayload(payloads))
    var shared: C = CleanupAdd(item, item)
    var deep: C = shared
    for _ in range(1_000_000):
        deep = CleanupAdd(deep, item)
    deep = one
    shared = one
    assert_equal(payloads.live(), 1)
    # `item` is used here, so it holds the payload until this point.
    assert_equal(item.isa[CleanupHeld](), True)
    assert_equal(payloads.made[], 1)
    assert_equal(payloads.live(), 0)

    # Success: the intermediate results are released and the final one returned.
    assert_equal(run(C(CleanupAdd(one, C(CleanupAdd(one, one)))), results), 3)
    assert_equal(results.live(), 0)

    # A declining guard keeps copies of the evaluated fields for the next clause.
    var hundred: C = CleanupLeaf(101)
    assert_equal(run(C(CleanupAdd(hundred, one)), results), 100)
    assert_equal(run(C(CleanupAdd(one, hundred)), results), 102)
    assert_equal(results.live(), 0)

    # A raise releases the results already computed for pending values.
    var failing: C = CleanupAdd(C(CleanupAdd(one, one)), C(CleanupAdd(one, C(CleanupLeaf(-7)))))
    assert_equal(run(failing, results), -1007)
    assert_equal(results.live(), 0)

    # Shared values are matched once; their results are copied to each use.
    var dag: C = one
    for _ in range(6):
        dag = CleanupAdd(dag, dag)
    assert_equal(run(dag, results), 64)
    assert_equal(results.live(), 0)

    # Next continues with a value; the replaced value's partial work is released.
    var chosen: C = CleanupPick(C(CleanupAdd(one, one)), C(CleanupAdd(one, C(CleanupHeld(CleanupPayload(payloads))))))
    assert_equal(run(chosen, results), 1)
    assert_equal(results.live(), 0)
    chosen = one
    assert_equal(payloads.live(), 0)
