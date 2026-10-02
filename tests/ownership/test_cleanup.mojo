from fp.algebra import map, ResultFamily
from fp.data import Result, Ok, Err
from fp.adt import Data, Cases, Node, Value
import fp
from std.testing import assert_equal
from std.memory import ArcPointer


@fieldwise_init
struct Resource(Movable):
    var counter: ArcPointer[Int]
    var value: Int

    def __deinit__(deinit self):
        self.counter[] += 1


@fieldwise_init
struct Leaf(Copyable):
    var id: Int


@fieldwise_init
struct Branch[R: Value](Movable):
    var children: List[Self.R]


struct Tree(Data):
    comptime Layer[R: Value] = Cases[Leaf, Branch[R]]


@fieldwise_init
struct CleanupRun(Copyable):
    var counter: ArcPointer[Int]
    var fail: Bool


@fieldwise_init
struct CleanupFailure(Copyable, Writable):
    var node: Int


def native_reference(
    counter: ArcPointer[Int], node: Int, fail: Bool
) raises CleanupFailure -> Resource:
    var children = List[Resource]()
    for i in range(3 if node == 0 else 0):
        children.append(native_reference(counter, i + 1, fail))
    if fail and node == 3:
        raise CleanupFailure(node)
    return Resource(counter, node)


def leaf_resource(leaf: Leaf, run: CleanupRun) raises CleanupFailure -> Resource:
    if run.fail and leaf.id == 3:
        raise CleanupFailure(leaf.id)
    return Resource(run.counter, leaf.id)


def branch_resource(branch: Branch[Resource], run: CleanupRun) raises CleanupFailure -> Resource:
    return Resource(run.counter, 0)


def run_recursive(counter: ArcPointer[Int], fail: Bool, native: Bool):
    comptime T = Node[Tree]
    try:
        if native:
            var result = native_reference(counter, 0, fail)
            debug_assert[assert_mode="safe"](result.value == 0)
        else:
            var tree: T = Branch([T(Leaf(1)), T(Leaf(2)), T(Leaf(3))])
            # The leaves' results move into the branch's argument; when leaf 3
            # raises, the results of leaves 1 and 2 are released.
            var result = fp.match(tree, leaf_resource, branch_resource, context=CleanupRun(counter, fail))
            debug_assert[assert_mode="safe"](result.value == 0)
    except error:
        debug_assert[assert_mode="safe"](fail and error.node == 3)


def preserve(var item: Resource) -> Resource:
    item.value += 1
    return item^


def run_result(counter: ArcPointer[Int], success: Bool):
    comptime R = Resource
    var value: Result[R, R]
    if success:
        value = Result[R, R](Ok(R(counter, 10)))
    else:
        value = Result[R, R](Err(R(counter, 20)))
    var mapped = map[ResultFamily[type_of(value).Error]](preserve, value^)
    debug_assert[assert_mode="safe"](mapped.is_ok() == success)


def main() raises:
    for failure in range(2):
        var native_destroyed = ArcPointer(0)
        var folded_destroyed = ArcPointer(0)
        run_recursive(native_destroyed, Bool(failure), True)
        run_recursive(folded_destroyed, Bool(failure), False)
        assert_equal(folded_destroyed[], native_destroyed[])
        assert_equal(folded_destroyed[], 2 if failure else 4)
    for success in range(2):
        var destroyed = ArcPointer(0)
        run_result(destroyed, Bool(success))
        assert_equal(destroyed[], 1)
