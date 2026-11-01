"""Explicit element selection infers native families and preserves their capabilities."""
from fp.functions import pipeline, Identity
from fp.data import NonEmptyList
from std.collections import Array, Deque, LinkedList
from std.testing import assert_equal


def ce_label(var value: Int) -> String: return String(value)
def ce_size(var value: String) -> Int: return value.byte_length()
def ce_positive(value: Int) -> Bool: return value > 0
def ce_whole(var value: Array[Int, 2]) -> Int: return len(value)


def ce_forward[T: Movable & Deinitable, N: Int](var values: Array[T, N]) -> Array[T, N]:
    return pipeline(values^).elements().map(Identity[T]()).get()


@fieldwise_init
struct CEFailure(Movable):
    var code: Int


def ce_checked(var value: Int) raises CEFailure -> Int:
    if value < 0: raise CEFailure(value)
    return value * 2


def main() raises:
    var a: Array[Int, 2] = [7, 42]
    var lengths = pipeline(a^).elements().map(ce_label).map(ce_size).get()
    comptime assert type_of(lengths) == Array[Int, 2]
    assert_equal(lengths[0], 1)
    assert_equal(lengths[1], 2)
    assert_equal(ce_forward(lengths^)[1], 2)
    var whole: Array[Int, 2] = [1, 2]
    assert_equal(pipeline(whole^).map(ce_whole).get(), 2)

    var calls = 0
    def counted(var value: Int) {mut calls} -> Int:
        calls += 1
        return value
    var empty = Array[Int, 0]()
    var selected = pipeline(empty^).elements()
    assert_equal(calls, 0)
    assert_equal(len(selected^.map(counted).get()), 0)
    assert_equal(calls, 0)

    var queue = Deque[Int]()
    queue.append(-1)
    queue.append(42)
    var labels = pipeline(queue^).filter(ce_positive).map(ce_label).get()
    comptime assert type_of(labels) == Deque[String]
    assert_equal(labels.pop(), "42")
    var linked = LinkedList[Int]()
    linked.append(3)
    linked.append(42)
    var linked_lengths = pipeline(linked^).map(ce_label).map(ce_size).get()
    comptime assert type_of(linked_lengths) == LinkedList[Int]
    assert_equal(List(linked_lengths), [1, 2])

    var nonempty = pipeline(NonEmptyList(3)).map(ce_label).get()
    comptime assert type_of(nonempty) == NonEmptyList[String]
    assert_equal(nonempty.first(), "3")
    var filtered = pipeline(NonEmptyList(-1)).filter(ce_positive).get()
    comptime assert type_of(filtered) == List[Int]
    assert_equal(len(filtered), 0)
    var list: List[Int] = [3]
    assert_equal(pipeline(list^).map(ce_label).get(), List[String](["3"]))

    var bad: Array[Int, 2] = [7, -9]
    var code = 0
    try:
        _ = pipeline(bad^).raising[CEFailure]().elements().map(ce_checked).get()
    except error:
        comptime assert type_of(error) == CEFailure
        code = error.code
    assert_equal(code, -9)
