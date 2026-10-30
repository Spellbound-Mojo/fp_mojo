"""Origin-explicit contexts and admitted owned captures survive repeated kernel calls."""
from fp.iteration import fold_left, reduce_optional, fold_until
from fp.data import ControlFlow, Continue
from fp.iteration import find, any, all
from std.iter import iter
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct State(Movable):
    var identity: Int
    var calls: Int
    var destroyed: ArcPointer[List[Int]]

    def __deinit__(deinit self):
        self.destroyed[].append(self.identity)


def exercise(destroyed: ArcPointer[List[Int]]) raises:
    var state = State(1, 0, destroyed)
    def step(var accumulator: Int, var item: Int) {var state^} -> Int:
        state.calls += 1
        return accumulator - item * state.calls
    assert_equal(fold_left(iter(range(1, 3)), 100, step), 95)
    assert_equal(fold_left(iter(range(1, 3)), 100, step), 89)
    var reduced = reduce_optional(iter(range(1, 4)), step)
    assert_equal(reduced.take(), -27)

    var control_state = State(2, 0, destroyed)
    # Native O3 miscompiles the owned-mutable capture with this String/sum
    # result shape. Keep this origin-explicit control; see CQ-3 native-state.
    def control(var accumulator: String, var item: Int) raises Never {mut control_state} -> ControlFlow[Int, String]:
        control_state.calls += 1
        return ControlFlow[Int, String](Continue(accumulator + String(item * control_state.calls)))
    var controlled = fold_until(iter(range(1, 3)), String("x"), control)
    assert_equal(controlled^.unwrap[Continue[String]]().into_payload(), "x14")
    var controlled_again = fold_until(iter(range(1, 3)), String("x"), control)
    assert_equal(controlled_again^.unwrap[Continue[String]]().into_payload(), "x38")

    var search_state = State(3, 0, destroyed)
    def predicate(item: Int) raises Never {mut search_state} -> Bool:
        search_state.calls += 1
        return item == search_state.calls
    var selected = find(iter(range(3, 6)), predicate)
    assert_equal(Bool(selected), False)
    assert_equal(any(iter(range(4, 5)), predicate), True)
    assert_equal(all(iter(range(5, 7)), predicate), True)

    # Later native uses keep each captured owner live at this observation;
    # Mojo otherwise destroys a closure immediately after its final use.
    assert_equal(len(destroyed[]), 0)
    assert_equal(step(0, 0), 0)
    var final_control = control(String("z"), 0)
    assert_equal(final_control^.unwrap[Continue[String]]().into_payload(), "z0")
    assert_equal(predicate(7), True)


def main() raises:
    var destroyed = ArcPointer(List[Int]())
    exercise(destroyed)
    assert_equal(len(destroyed[]), 3)
    for identity in range(1, 4):
        var count = 0
        for actual in destroyed[]:
            count += Int(actual == identity)
        assert_equal(count, 1)
