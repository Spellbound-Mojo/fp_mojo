"""`Node` storage against a hand-written shared tree: build, traverse, release, revisions.

The native side is what a Mojo programmer writes without the library: an
immutable binary tree whose nodes are `ArcPointer` cells, shared on copy and
released by their destructors. Both sides build the same values in the same
order. The suite runs this program at O3 and reports each line as a diagnostic;
the timings never fail the suite. Each line is
`bench <name> native_ns=<median> library_ns=<median> samples=<n>`.

- `node_build`, `node_traverse`, `node_drop`: a complete tree of 262,143 nodes,
  larger than the caches, built, summed by recursion, and released.
- `match_large`: `fp.match` over that `Node` tree against recursion over the same tree.
- `node_revisions`: 32 path-copy edits of a 65,535-node tree with the last 8
  revisions kept alive, each new revision summed (by `fp.match` on the library
  side); dropped revisions release only the nodes no other revision shares.
"""
import fp
from fp.adt import Data, Cases, Node, Value
from std.memory import ArcPointer
from std.time import perf_counter_ns
from std.testing import assert_equal


# ----------------------------------------------------------------- library side

@fieldwise_init
struct NodeLeaf(Copyable):
    var value: Int


@fieldwise_init
struct NodePair[R: Value](Movable):
    var left: Self.R
    var right: Self.R


struct NodeTree(Data):
    comptime Layer[R: Value] = Cases[NodeLeaf, NodePair[R]]


comptime N = Node[NodeTree]


def node_build(depth: Int, value: Int) -> N:
    if depth == 0:
        return NodeLeaf(value % 7)
    return NodePair(node_build(depth - 1, value * 3 + 1), node_build(depth - 1, value * 5 + 2))


def node_sum(x: N) -> Int:
    if x.isa[NodeLeaf]():
        return x[NodeLeaf].value
    ref p = x[NodePair[N]]
    return node_sum(p.left) + node_sum(p.right)


def node_match(x: N) -> Int:
    return fp.match(x,
        lambda (l: NodeLeaf) -> Int: l.value,
        lambda (p: NodePair[Int]) -> Int: p.left + p.right)


def node_edit(x: N, depth: Int, path: Int, value: Int) -> N:
    """Replace the leaf `path` selects, copying the nodes above it and sharing the rest."""
    if depth == 0:
        return NodeLeaf(value)
    ref p = x[NodePair[N]]
    if (path >> (depth - 1)) & 1:
        return NodePair(p.left, node_edit(p.right, depth - 1, path, value))
    return NodePair(node_edit(p.left, depth - 1, path, value), p.right)


# ----------------------------------------------------------------- native side

struct HandCell(Movable):
    var value: Int
    var left: Optional[HandTree]
    var right: Optional[HandTree]

    def __init__(out self, value: Int, var left: Optional[HandTree], var right: Optional[HandTree]):
        self.value = value
        self.left = left^
        self.right = right^


struct HandTree(ImplicitlyCopyable, Movable):
    var cell: ArcPointer[HandCell]

    def __init__(out self, value: Int):
        self.cell = ArcPointer(HandCell(value, None, None))

    def __init__(out self, var left: HandTree, var right: HandTree):
        self.cell = ArcPointer(HandCell(0, Optional(left^), Optional(right^)))

    def __init__(out self, *, copy: Self):
        self.cell = copy.cell

    def __deinit__(deinit self):
        # Declared so the recursive type's Deinitable conformance does not
        # depend on its own fields; the suite imports this program as a module,
        # where Mojo 1.2 cannot otherwise establish it.
        pass


def hand_build(depth: Int, value: Int) -> HandTree:
    if depth == 0:
        return HandTree(value % 7)
    return HandTree(hand_build(depth - 1, value * 3 + 1), hand_build(depth - 1, value * 5 + 2))


def hand_sum(t: HandTree) -> Int:
    ref c = t.cell[]
    if not c.left:
        return c.value
    return hand_sum(c.left.value()) + hand_sum(c.right.value())


def hand_edit(t: HandTree, depth: Int, path: Int, value: Int) -> HandTree:
    if depth == 0:
        return HandTree(value)
    ref c = t.cell[]
    if (path >> (depth - 1)) & 1:
        return HandTree(c.left.value(), hand_edit(c.right.value(), depth - 1, path, value))
    return HandTree(hand_edit(c.left.value(), depth - 1, path, value), c.right.value())


# ----------------------------------------------------------------- samples

comptime LARGE = 17
comptime REVISED = 15
comptime EDITS = 32
comptime KEPT = 8

comptime BUILD = 0
comptime TRAVERSE = 1
comptime DROP = 2
comptime MATCH = 3
comptime REVISIONS = 4


@no_inline
def library_sample[kind: Int](large: N, hand: HandTree) -> Tuple[Int, Int]:
    """Time one library-side measurement; returns (nanoseconds, checksum)."""
    var start: Int
    var elapsed: Int
    var checksum: Int
    comptime if kind == BUILD:
        start = perf_counter_ns()
        var tree = node_build(LARGE, 1)
        elapsed = Int(perf_counter_ns() - start)
        checksum = node_sum(tree)
    elif kind == TRAVERSE:
        start = perf_counter_ns()
        checksum = node_sum(large)
        elapsed = Int(perf_counter_ns() - start)
    elif kind == DROP:
        var tree = node_build(LARGE, 1)
        checksum = node_sum(tree)
        start = perf_counter_ns()
        _ = tree^
        elapsed = Int(perf_counter_ns() - start)
    elif kind == MATCH:
        start = perf_counter_ns()
        checksum = node_match(large)
        elapsed = Int(perf_counter_ns() - start)
    else:
        var revisions = List[N](capacity=KEPT)
        revisions.append(node_build(REVISED, 3))
        checksum = 0
        start = perf_counter_ns()
        for edit in range(EDITS):
            var next = node_edit(revisions[len(revisions) - 1], REVISED, edit * 2654435761, edit)
            checksum += node_match(next)
            if len(revisions) == KEPT:
                _ = revisions.pop(0)
            revisions.append(next^)
        elapsed = Int(perf_counter_ns() - start)
    return (elapsed, checksum)


@no_inline
def native_sample[kind: Int](large: N, hand: HandTree) -> Tuple[Int, Int]:
    """Time one native-side measurement; returns (nanoseconds, checksum)."""
    var start: Int
    var elapsed: Int
    var checksum: Int
    comptime if kind == BUILD:
        start = perf_counter_ns()
        var tree = hand_build(LARGE, 1)
        elapsed = Int(perf_counter_ns() - start)
        checksum = hand_sum(tree)
    elif kind == TRAVERSE:
        start = perf_counter_ns()
        checksum = hand_sum(hand)
        elapsed = Int(perf_counter_ns() - start)
    elif kind == DROP:
        var tree = hand_build(LARGE, 1)
        checksum = hand_sum(tree)
        start = perf_counter_ns()
        _ = tree^
        elapsed = Int(perf_counter_ns() - start)
    elif kind == MATCH:
        # The same Node tree, by hand-written recursion: only the engine differs.
        start = perf_counter_ns()
        checksum = node_sum(large)
        elapsed = Int(perf_counter_ns() - start)
    else:
        var revisions = List[HandTree](capacity=KEPT)
        revisions.append(hand_build(REVISED, 3))
        checksum = 0
        start = perf_counter_ns()
        for edit in range(EDITS):
            var next = hand_edit(revisions[len(revisions) - 1], REVISED, edit * 2654435761, edit)
            checksum += hand_sum(next)
            if len(revisions) == KEPT:
                _ = revisions.pop(0)
            revisions.append(next^)
        elapsed = Int(perf_counter_ns() - start)
    return (elapsed, checksum)


def median(var samples: List[Int]) -> Int:
    for i in range(1, len(samples)):
        var j = i
        while j > 0 and samples[j - 1] > samples[j]:
            samples.swap_elements(j - 1, j)
            j -= 1
    return samples[len(samples) // 2]


def paired[kind: Int](name: String, large: N, hand: HandTree) raises:
    _ = native_sample[kind](large, hand)
    _ = library_sample[kind](large, hand)
    var native = List[Int]()
    var library = List[Int]()
    for index in range(9):
        # Alternate order; equal checksums show both sides did the same work.
        var first: Tuple[Int, Int]
        var second: Tuple[Int, Int]
        if index % 2:
            second = library_sample[kind](large, hand)
            first = native_sample[kind](large, hand)
        else:
            first = native_sample[kind](large, hand)
            second = library_sample[kind](large, hand)
        assert_equal(first[1], second[1])
        native.append(first[0])
        library.append(second[0])
    print("bench", name, "native_ns=" + String(median(native^)), "library_ns=" + String(median(library^)), "samples=9")


def main() raises:
    var large = node_build(LARGE, 1)
    var hand = hand_build(LARGE, 1)
    paired[BUILD]("node_build", large, hand)
    paired[TRAVERSE]("node_traverse", large, hand)
    paired[DROP]("node_drop", large, hand)
    paired[MATCH]("match_large", large, hand)
    paired[REVISIONS]("node_revisions", large, hand)
