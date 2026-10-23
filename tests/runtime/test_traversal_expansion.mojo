"""Derived traversal reuses source capabilities and target effect sequencing."""
from fp.functions import piped
from fp.iteration import iterated
from fp.combinators import sequence_void, flat_traverse, flat_sequence, traverse_filter
from fp.algebra import OptionalFamily, ListFamily, ResultFamily
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true

def tx_groups(x: Int) -> Optional[List[Int]]:
    var xs: List[Int] = [x, x + 10]
    return Optional(xs^)
def tx_select(x: Int) -> Result[Optional[Int], String]:
    if x % 2 == 0: return Ok(Optional(x * 10))
    return Ok(Optional[Int]())
def tx_nested(x: Int) -> Optional[Result[Int, String]]: return Optional(Result[Int, String](Ok(x*2)))
def tx_accept(x: Int) -> Optional[Bool]: return Optional(x % 2 == 0)
def main() raises:
    var filtered = piped(List[Int]()).filter_effect[OptionalFamily](tx_accept).get()
    assert_equal(filtered.take(), List[Int]())
    var values: List[Int] = [1, 2, 3, 4]
    var tx_selected = iterated(values^).filter_effect[OptionalFamily](tx_accept)
    assert_equal(tx_selected.take(), [2, 4])

    var xs: List[Int] = [1, 2, 3]
    var a = piped(xs.copy()).flat_traverse[OptionalFamily](tx_groups).get()
    assert_equal(a.take(), [1, 11, 2, 12, 3, 13])
    var b = iterated(xs.copy()).flat_traverse[OptionalFamily](tx_groups)
    assert_equal(b.take(), [1, 11, 2, 12, 3, 13])
    var c = traverse_filter[ResultFamily[String]](tx_select, xs.copy())
    assert_equal(c^.raise_on_err(), [20])
    var d = piped(xs.copy()).traverse_filter[ResultFamily[String]](tx_select).get()
    assert_equal(d^.raise_on_err(), [20])
    var es: List[Optional[Int]] = [Optional(1), Optional(2)]
    assert_true(sequence_void[OptionalFamily](es.copy()))
    assert_true(piped(es.copy()).sequence_void[OptionalFamily]().get())
    var fs: List[Optional[List[Int]]] = [tx_groups(1), tx_groups(2)]
    var sequenced = piped(fs^).flat_sequence[OptionalFamily]().get()
    assert_equal(sequenced.take(), [1, 11, 2, 12])
    var r = piped(Result[Int, String](Ok(3))).flat_traverse[OptionalFamily](tx_nested).get()
    assert_equal(r.take().raise_on_err(), 6)
    var s = piped(Result[Int, String](Err(String("source")))).flat_traverse[OptionalFamily](tx_nested).get()
    assert_true(s.take().is_err())
    var z = piped(Result[Optional[Int], String](Err(String("source")))).sequence_void[OptionalFamily]().get()
    assert_true(z.take().is_err())
    tx_effects()
    tx_sources()
    tx_deferred()


from fp.callables import as_unary, BorrowOnceCallable, OnceUnary
from fp.effects import Reader, State, action, run
from std.memory import ArcPointer
from std.collections import Array, Deque, LinkedList
from std.testing import assert_false
from algebra_support.iterators import Counted
from test_algebra_third_party import Cell, CellFamily
from test_combinators import CombinatorRestarting


def tx_pair() -> List[Int]: return [1, 2]
def tx_four() -> List[Int]: return [1, 2, 3, 4]


def tx_effects() raises:
    var pulls = 0
    var calls = ArcPointer(0)
    def checked(x: Int) {calls} -> Result[Bool, String]:
        calls[] += 1
        if x == 3: return Err(String("stop"))
        return Ok(x == 2)
    var failed = iterated(Counted(Pointer(to=pulls), 0, 6)).filter_effect[ResultFamily[String]](checked)
    assert_true(failed.is_err())
    assert_equal(pulls, 3)
    assert_equal(calls[], 3)
    calls[] = 0
    def optional(x: Int) {calls} -> Optional[Bool]:
        calls[] += 1
        if x == 3: return None
        return Optional(x == 2)
    assert_false(piped(tx_four()).filter_effect[OptionalFamily](optional).get())
    assert_equal(calls[], 3)
    calls[] = 0
    def decisions(x: Int) {calls} -> List[Bool]:
        calls[] += 1
        return [False, True]
    var branches = piped(tx_pair()).filter_effect[ListFamily](decisions).get()
    assert_equal(len(branches), 4)
    assert_equal(branches[0], List[Int]())
    assert_equal(branches[1], [2])
    assert_equal(branches[2], [1])
    assert_equal(branches[3], [1, 2])
    assert_equal(calls[], 2)
    def alternatives(x: Int) -> List[List[Int]]:
        var first: List[Int] = [x]
        var second: List[Int] = [x, x * 10]
        return [first^, second^]
    var flattened = piped(tx_pair()).flat_traverse[ListFamily](alternatives).get()
    assert_equal(flattened[0], [1, 2])
    assert_equal(flattened[1], [1, 2, 20])
    assert_equal(flattened[2], [1, 10, 2])
    assert_equal(flattened[3], [1, 10, 2, 20])
    def no_items(x: Int) -> Optional[List[Int]]: return Optional(List[Int]())
    var empty_success = piped(tx_pair()).flat_traverse[OptionalFamily](no_items).get()
    assert_equal(empty_success.take(), List[Int]())
    var empty_source = iterated(List[Int]()).traverse_filter[ResultFamily[String]](tx_select)
    assert_equal(empty_source^.raise_on_err(), List[Int]())
    def cell(x: Int) -> Cell[Optional[Int]]:
        if x % 2 == 0: return Cell(Optional(x * 10))
        return Cell(Optional[Int]())
    assert_equal(piped(tx_four()).traverse_filter[CellFamily](cell).get().take(), [20, 40])
    var es: List[Optional[Int]] = [Optional(1), Optional[Int](), Optional(3)]
    assert_false(iterated(es^).sequence_void[OptionalFamily]())
    var fs: List[Optional[List[Int]]] = [tx_groups(1), Optional[List[Int]]()]
    assert_false(flat_sequence[OptionalFamily](fs^))


def tx_sources() raises:
    var kept = piped(Optional(2)).filter_effect[OptionalFamily](tx_accept).get()
    assert_equal(kept.take().value(), 2)
    var removed = piped(Optional(1)).filter_effect[OptionalFamily](tx_accept).get()
    assert_false(removed.take())
    var absent = piped(Optional[Int]()).traverse_filter[ResultFamily[String]](tx_select).get()
    assert_false(absent^.raise_on_err())
    def nested_optional(x: Int) -> Optional[Optional[Int]]: return Optional(Optional(x * 10))
    var flat = piped(Optional(3)).flat_traverse[OptionalFamily](nested_optional).get()
    assert_equal(flat.take().value(), 30)
    var optional_sequence = piped(Optional(nested_optional(4))).flat_sequence[OptionalFamily]().get()
    assert_equal(optional_sequence.take().value(), 40)
    var optional_void = piped(Optional(Optional(2))).sequence_void[OptionalFamily]().get()
    assert_true(optional_void)
    var array: Array[Optional[Int], 2] = [Optional(1), Optional(2)]
    assert_true(piped(array^).sequence_void[OptionalFamily]().get())
    var deque = Deque[Optional[Int]]()
    deque.append(Optional(1))
    assert_true(piped(deque^).sequence_void[OptionalFamily]().get())
    var linked = LinkedList[Optional[Int]]()
    linked.append(Optional(1))
    assert_true(piped(linked^).sequence_void[OptionalFamily]().get())
    def inner_error(x: Int) -> Result[Result[Int, String], Int]: return Ok(Result[Int, String](Err(String("inner"))))
    var inner = piped(Result[Int, String](Ok(2))).flat_traverse[ResultFamily[Int]](inner_error).get().raise_on_err()
    assert_equal(inner^._take_err(), "inner")
    def target_error(x: Int) -> Result[Result[Int, String], Int]: return Err(42)
    var outer = piped(Result[Int, String](Ok(2))).flat_traverse[ResultFamily[Int]](target_error).get()
    assert_equal(outer^._take_err(), 42)
    var nested_source = Result[Optional[Result[Int, String]], String](Ok(tx_nested(3)))
    var sequenced = piped(nested_source^).flat_sequence[OptionalFamily]().get()
    assert_equal(sequenced.take().raise_on_err(), 6)
    var current = CombinatorRestarting(2)
    var result = iterated(current^).filter_effect[OptionalFamily](tx_accept)
    assert_equal(result.take(), [2])
    var native = as_unary(tx_groups)
    var result2 = flat_traverse[OptionalFamily](native^, tx_pair())
    assert_equal(result2.take(), [1, 11, 2, 12])


@fieldwise_init
struct TXReadGroup(BorrowOnceCallable):
    var value: Int
    comptime Payload = Int
    comptime Result = List[Int]
    def invoke_once(deinit self, ref env: Int) raises Never capturing -> List[Int]:
        return [self.value, self.value + env]


@fieldwise_init
struct TXStateDecision(OnceUnary):
    var value: Int
    comptime Arg = Int
    comptime Out = Tuple[Bool, Int]
    def call_once(deinit self, var state: Int) -> Self.Out:
        return (self.value % 2 == 0, state + self.value)


def tx_deferred() raises:
    var calls = ArcPointer(0)
    var pulls = 0
    def groups(x: Int) {calls} -> type_of(action[Reader[Int], List[Int]](TXReadGroup(0))):
        calls[] += 1
        return action[Reader[Int], List[Int]](TXReadGroup(x))
    var reader = iterated(Counted(Pointer(to=pulls), 0, 2)).flat_traverse[Reader[Int]](groups)
    assert_equal(calls[], 0)
    assert_equal(pulls, 0)
    var env = 10
    assert_equal(run[Reader[Int]](reader^, env), [1, 11, 2, 12])
    assert_equal(calls[], 2)
    assert_equal(pulls, 3)
    calls[] = 0
    def decision(x: Int) {calls} -> type_of(action[State[Int], Bool](TXStateDecision(0))):
        calls[] += 1
        return action[State[Int], Bool](TXStateDecision(x))
    var state = piped(tx_four()).filter_effect[State[Int]](decision).get()
    assert_equal(calls[], 0)
    var output = run[State[Int]](state^, 10)
    assert_equal(output[0], [2, 4])
    assert_equal(output[1], 20)
    assert_equal(calls[], 4)
