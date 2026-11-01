"""Infer pair types and preserve native signatures and callback receiver modes."""
from fp.functions import untupled, Untupled, tupled, split, as_unary, flow
from fp.callables import Unary, MutableUnary, OnceUnary, Binary, MutableBinary, OnceBinary
from fp.iteration import iterated
from std.testing import assert_equal

def total(var pair: Tuple[Int, Int]) -> Int: return pair[0] + pair[1]
def difference(var pair: Tuple[Int, Int]) -> Int: return pair[0] - pair[1]
def label(var pair: Tuple[Int, Int]) -> String: return String(total(pair))
def report(var pair: Tuple[Int, String]) -> String: return String(pair[0]) + pair[1]
def size(var pair: Tuple[Int, String]) -> Int: return pair[0] + pair[1].byte_length()
def increment(var value: Int) -> Int: return value + 1
def discard[T: Movable & Deinitable](var pair: T): pass
def unit(var pair: Tuple[Int, Int]) -> NoneType: return None
def fail[T: Movable & Deinitable, R: Movable & Deinitable](var pair: T) raises Int -> R: raise 7
def fail_void[T: Movable & Deinitable](var pair: T) raises Int: raise 8
def never(var pair: Tuple[Int, Int]) raises Never -> Int: return total(pair)

@fieldwise_init
struct Modes(Unary, MutableUnary, OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int
    var calls: Int
    def call(self, var pair: Self.Arg) -> Int: return total(pair)
    def call_mut(mut self, var pair: Self.Arg) -> Int:
        self.calls += 1
        return total(pair) + self.calls
    def call_once(deinit self, var pair: Self.Arg) -> Int: return total(pair) + 100

@fieldwise_init
struct Stateful(MutableUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int
    var calls: Int
    def call_mut(mut self, var pair: Self.Arg) -> Int:
        self.calls += 1
        return total(pair) + self.calls

@fieldwise_init
struct Consume(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int
    def call_once(deinit self, var pair: Self.Arg) -> Int: return total(pair)

def generic[A: Movable & Deinitable, B: Movable & Deinitable, F: Unary](
    var callback: F, var first: A, var second: B
) raises Untupled[A, B, F].Error -> F.Out where F.Arg == Tuple[A, B]:
    return untupled[A, B](callback^)(first^, second^)

def workflows() raises:
    var sum = untupled(total)
    assert_equal(sum(2, 3), 5)
    assert_equal(iterated(range(1, 4)).scan_left(sum, 0).collect_list(), [0, 1, 3, 6])
    assert_equal(iterated(range(1, 4)).zip_with(range(4, 7), sum).collect_list(), [5, 7, 9])
    assert_equal(sum(4, 5), 9)
    assert_equal(generic(as_unary(report), 2, String("!")), "2!")
    assert_equal(untupled(split(increment, increment))(2, 3), (3, 4))
    assert_equal(untupled(total).then(increment)(2, 3), 6)
    assert_equal(flow(untupled(total), increment)(2, 3), 6)
    var offset = 7
    def captured(var pair: Tuple[Int, Int]) {offset} -> Int: return total(pair) + offset
    assert_equal(untupled(as_unary(captured))(2, 3), 12)
    var modes = untupled(Modes(0))
    assert_equal(modes(2, 3), 5)
    assert_equal(modes.call_mut(2, 3), 6)
    assert_equal(modes.call_mut(2, 3), 7)
    assert_equal(modes^.call_once(2, 3), 105)
    var mutable = untupled(Stateful(0))
    comptime assert conforms_to(type_of(mutable), MutableBinary)
    comptime assert not conforms_to(type_of(mutable), Binary)
    assert_equal(mutable.call_mut(2, 3), 6)
    assert_equal(iterated(range(1, 4)).scan_left(mutable^, 0).collect_list(), [0, 3, 8, 15])
    var once = untupled(Consume())
    comptime assert conforms_to(type_of(once), OnceBinary)
    comptime assert not conforms_to(type_of(once), MutableBinary)
    assert_equal(once^.call_once(2, 3), 5)

def pointers() raises:
    var rr: def(var Tuple[Int, Int]) thin -> Int = total
    var saved = untupled(rr)
    rr = difference
    assert_equal(saved(2, 3), 5)
    assert_equal(untupled(rr)(2, 3), -1)
    var rm: def(var Tuple[Int, Int]) thin -> String = label
    var mr: def(var Tuple[Int, String]) thin -> Int = size
    var mm: def(var Tuple[Int, String]) thin -> String = report
    assert_equal(untupled(rm)(2, 3), "5")
    assert_equal(untupled(mr)(2, String("abc")), 5)
    assert_equal(untupled(mm)(2, String("!")), "2!")

def errors[T: Movable & Deinitable, R: Movable & Deinitable, A: Movable & Deinitable, B: Movable & Deinitable](
    var first: A, var second: B
) raises where T == Tuple[A, B]:
    var pointer: def(var T) raises Int thin -> R = fail[T, R]
    var adapted = untupled[A, B](pointer)
    comptime assert type_of(adapted).Error == Int
    var observed = 0
    try: _ = adapted(first^, second^)
    except error: observed = error
    assert_equal(observed, 7)

def procedures[A: Copyable & Deinitable, B: Copyable & Deinitable](
    first: A, second: B
) raises:
    comptime T = Tuple[A, B]
    var pointer: def(var T) thin = discard[T]
    var procedure = untupled[A, B](pointer)
    comptime assert type_of(procedure).Out == type_of(None)
    procedure(first.copy(), second.copy())
    var raising: def(var T) raises Int thin = fail_void[T]
    var observed = 0
    try: untupled[A, B](raising)(first.copy(), second.copy())
    except error: observed = error
    assert_equal(observed, 8)

def main() raises:
    workflows()
    pointers()
    errors[Tuple[Int, Int], Int](2, 3)
    errors[Tuple[Int, Int], String](2, 3)
    errors[Tuple[Int, String], Int](2, String("x"))
    errors[Tuple[Int, String], String](2, String("x"))
    procedures(2, 3)
    procedures(2, String("x"))
    var impossible: def(var Tuple[Int, Int]) raises Never thin -> Int = never
    assert_equal(untupled(impossible)(2, 3), 5)
    var explicit_none = untupled(unit)
    comptime assert type_of(explicit_none).Out == NoneType
    _ = explicit_none(2, 3)
