"""Node values: construction, inspection, sharing, height and release of deep values."""
import fp
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

@fieldwise_init
struct NodesW0(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW1(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW2(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW3(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW4(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW5(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW6(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW7(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW8(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW9(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW10(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW11(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW12(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW13(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW14(Copyable, Equatable):
    var value: Int

@fieldwise_init
struct NodesW15(Copyable, Equatable):
    var value: Int


@fieldwise_init
struct NodesWidePair[R: Value](Movable):
    var left: Self.R
    var right: Self.R


struct NodesWideTree(Data):
    """Seventeen constructors: more than a handle's low bits can name."""
    comptime Layer[R: Value] = Cases[NodesW0, NodesW1, NodesW2, NodesW3, NodesW4, NodesW5, NodesW6, NodesW7, NodesW8, NodesW9, NodesW10, NodesW11, NodesW12, NodesW13, NodesW14, NodesW15, NodesWidePair[R]]


comptime W = Node[NodesWideTree]


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
    assert_equal(one._height(), 1)
    assert_equal(pair._height(), 2)
    var many: T = NodesMany(String("m"), [pair, one, T(NodesMaybe(Optional[T](None)))])
    assert_equal(many._height(), 3)
    var maybe: T = NodesMaybe(Optional[T](many))
    assert_equal(maybe._height(), 4)
    var empty: T = NodesMany(String("e"), List[T]())
    assert_equal(empty._height(), 1)
    assert_equal(many[NodesMany[T]].label, "m")
    assert_equal(len(many[NodesMany[T]].items), 3)

    # A value a million levels deep is built and released without recursion.
    var deep: T = NodesLeaf(0)
    for _ in range(1_000_000):
        deep = NodesPair(deep, one)
    assert_equal(deep._height(), 1_000_001)
    deep = one
    assert_true(deep is one)

    # A shared value survives the release of one of its holders.
    var holder: T = NodesPair(pair, pair)
    _ = holder^
    assert_equal(pair[NodesPair[T]].left[NodesLeaf].value, 1)

    # A type with more than 16 constructors keeps the constructor in the cell.
    var w0: W = NodesW0(10)
    var w15: W = NodesW15(25)
    var wide: W = NodesWidePair(w0, w15)
    assert_true(w0.isa[NodesW0]())
    assert_false(w0.isa[NodesW15]())
    assert_true(w15.isa[NodesW15]())
    assert_equal(w15[NodesW15].value, 25)
    assert_true(w15 == NodesW15(25))
    assert_false(w15 == NodesW14(25))
    assert_true(wide.isa[NodesWidePair[W]]())
    assert_true(wide[NodesWidePair[W]].left is w0)
    assert_equal(wide._height(), 2)
    var total = fp.match(wide,
        lambda (p: NodesWidePair[Int]) -> Int: p.left + p.right,
        lambda (k: NodesW0) -> Int: k.value,
        lambda (k: NodesW15) -> Int: k.value,
        lambda (e: W) -> Int: 0)
    assert_equal(total, 35)
    var wide_deep: W = NodesW7(0)
    for _ in range(100_000):
        wide_deep = NodesWidePair(wide_deep, w0)
    assert_equal(wide_deep._height(), 100_001)
    wide_deep = w0
    assert_true(wide_deep is w0)
