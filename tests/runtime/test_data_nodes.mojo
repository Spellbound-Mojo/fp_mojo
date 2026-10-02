"""Node values: construction, inspection, sharing, height and release of deep values."""
from fp.adt import Data, Cases, Node, Value
from std.testing import assert_equal, assert_true, assert_false


@fieldwise_init
struct NodesLeaf(Copyable, Equatable):
    var value: Int


@fieldwise_init
struct NodesPair[R: Value](Movable):
    var left: Self.R
    var right: Self.R


@fieldwise_init
struct NodesMany[R: Value](Movable):
    var label: String
    var items: List[Self.R]


@fieldwise_init
struct NodesMaybe[R: Value](Movable):
    var item: Optional[Self.R]


struct NodesTree(Data):
    comptime Layer[R: Value] = Cases[NodesLeaf, NodesPair[R], NodesMany[R], NodesMaybe[R]]


comptime T = Node[NodesTree]


def main() raises:
    var one: T = NodesLeaf(1)
    var two: T = NodesLeaf(2)
    var pair: T = NodesPair(one, two)

    # Inspection.
    assert_true(one.isa[NodesLeaf]())
    assert_false(one.isa[NodesPair[T]]())
    assert_true(pair.isa[NodesPair[T]]())
    assert_equal(one[NodesLeaf].value, 1)
    assert_true(one == NodesLeaf(1))
    assert_false(one == NodesLeaf(2))
    assert_false(pair == NodesLeaf(1))
    assert_true(pair[NodesPair[T]].left is one)
    assert_true(pair[NodesPair[T]].right[NodesLeaf] == NodesLeaf(2))

    # Copies share; equal values built separately are distinct nodes.
    var copy = pair
    assert_true(copy is pair)
    var again: T = NodesPair(one, two)
    assert_false(again is pair)

    # Height: the longest path to a leaf, counting the node itself.
    assert_equal(one._cell[].height, 1)
    assert_equal(pair._cell[].height, 2)
    var many: T = NodesMany(String("m"), [pair, one, T(NodesMaybe(Optional[T](None)))])
    assert_equal(many._cell[].height, 3)
    var maybe: T = NodesMaybe(Optional[T](many))
    assert_equal(maybe._cell[].height, 4)
    var empty: T = NodesMany(String("e"), List[T]())
    assert_equal(empty._cell[].height, 1)
    assert_equal(many[NodesMany[T]].label, "m")
    assert_equal(len(many[NodesMany[T]].items), 3)

    # A value a million levels deep is built and released without recursion.
    var deep: T = NodesLeaf(0)
    for i in range(1_000_000):
        deep = NodesPair(deep, one)
    assert_equal(deep._cell[].height, 1_000_001)
    deep = one
    assert_true(deep is one)

    # A shared value survives the release of one of its holders.
    var holder: T = NodesPair(pair, pair)
    holder = one
    assert_equal(pair[NodesPair[T]].left[NodesLeaf].value, 1)
