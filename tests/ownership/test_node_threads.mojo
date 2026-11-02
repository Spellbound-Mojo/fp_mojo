"""Node handles copied and released on several threads at once.

Four OS threads walk one shared tree, sharing its subtrees into new values and
releasing them, while the main thread drops its own handle; the last release of
each value may happen on any thread. Every value counts its own destruction, so
the totals show each was destroyed exactly once.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.testing import assert_equal
from fp.adt import Data, Cases, Node, Value
from fp._internal.os import OSThread, threads_supported


struct ThreadsCount(Movable):
    """Counts its own destruction."""

    var drops: ArcPointer[Atomic[Int]]

    def __init__(out self, drops: ArcPointer[Atomic[Int]]):
        self.drops = drops.copy()

    def __deinit__(deinit self):
        _ = self.drops[].fetch_add[ordering=Ordering.RELAXED](1)


@fieldwise_init
struct ThreadsLeaf(Movable):
    var count: ThreadsCount


@fieldwise_init
struct ThreadsPair[R: Value](Movable):
    var left: Self.R
    var right: Self.R
    var count: ThreadsCount


struct ThreadsTree(Data):
    comptime Layer[R: Value] = Cases[ThreadsLeaf, ThreadsPair[R]]


comptime TT = Node[ThreadsTree]
comptime DEPTH = 10
comptime ROUNDS = 20_000
comptime WORKERS = 4


def threads_build(depth: Int, drops: ArcPointer[Atomic[Int]]) -> TT:
    if depth == 0:
        return ThreadsLeaf(ThreadsCount(drops))
    return ThreadsPair(threads_build(depth - 1, drops), threads_build(depth - 1, drops), ThreadsCount(drops))


struct ThreadsState(Movable):
    var root: Optional[TT]
    var seed: Int
    var drops: ArcPointer[Atomic[Int]]
    var made: ArcPointer[Atomic[Int]]

    def __init__(out self, root: TT, seed: Int, drops: ArcPointer[Atomic[Int]], made: ArcPointer[Atomic[Int]]):
        self.root = Optional(root)
        self.seed = seed
        self.drops = drops.copy()
        self.made = made.copy()


def threads_worker(state: Pointer[ThreadsState, MutAnyOrigin]) abi("C") -> OptionalPointer[NoneType, MutUntrackedOrigin]:
    # The worker owns its handle to the root and releases it when it ends.
    var root = state[].root.take()
    var made = 0
    for round in range(ROUNDS):
        var path = (round * 2654435761 + state[].seed) & ((1 << DEPTH) - 1)
        var node = root
        for level in range(DEPTH - 1):
            ref pair = node[ThreadsPair[TT]]
            var next = pair.right if (path >> level) & 1 else pair.left
            # Share both children of this level into a new value, then release it.
            var fresh: TT = ThreadsPair(pair.left, pair.right, ThreadsCount(state[].drops))
            made += 1
            _ = fresh^
            node = next
    _ = state[].made[].fetch_add[ordering=Ordering.RELAXED](made)
    _ = root^
    return None


def main() raises:
    comptime if threads_supported:
        var drops = ArcPointer(Atomic[Int](0))
        var made = ArcPointer(Atomic[Int](0))
        var root = threads_build(DEPTH, drops)
        var workers = List[OSThread[ThreadsState]]()
        for seed in range(WORKERS):
            workers.append(OSThread(ArcPointer(ThreadsState(root, seed, drops, made)), threads_worker))
        _ = root^
        workers.clear()
        var built = (1 << (DEPTH + 1)) - 1
        assert_equal(made[].load(), WORKERS * ROUNDS * (DEPTH - 1))
        assert_equal(drops[].load(), built + made[].load())
