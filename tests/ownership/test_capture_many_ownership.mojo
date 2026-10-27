from fp.data import Capture, Result
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct CaptureManyOwner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

def choose(var first: CaptureManyOwner, var second: CaptureManyOwner, var third: CaptureManyOwner) raises CaptureManyOwner -> CaptureManyOwner:
    if first.value < 0:
        raise second^
    return third^

def discard(var first: CaptureManyOwner, var second: CaptureManyOwner, var third: CaptureManyOwner):
    pass

def forward[E: Movable & Deinitable, A: Movable & Deinitable,
            F: def(var A, var A, var A) raises E -> A](
    function: F, var first: A, var second: A, var third: A
) -> Result[A, E]:
    return Capture[E].args(first^, second^, third^).run(function)

def views[T: Copyable & Deinitable](var first: T, var second: T, var third: T) raises T -> T:
    raise second^

def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    var pointer: def(var View, var View, var View) raises View thin -> View = views[View]
    var error = Capture[View].args(view, view, view).run(pointer)
    comptime assert type_of(error) == Result[View, View]
    assert_equal(Pointer(to=error._err().value[1]) == Pointer(to=owner[1]), True)

def main() raises:
    var drops = ArcPointer(0)
    var success = Capture[CaptureManyOwner].args(CaptureManyOwner(1, drops), CaptureManyOwner(2, drops), CaptureManyOwner(3, drops)).run(choose)
    assert_equal(success._ok().value.value, 3)
    assert_equal(drops[], 2)
    _ = success^
    assert_equal(drops[], 3)
    var error = Capture[CaptureManyOwner].args(CaptureManyOwner(-1, drops), CaptureManyOwner(2, drops), CaptureManyOwner(3, drops)).run(choose)
    assert_equal(error._err().value.value, 2)
    assert_equal(drops[], 5)
    _ = error^
    assert_equal(drops[], 6)
    var pending = Capture[Never].args(CaptureManyOwner(1, drops), CaptureManyOwner(2, drops)).take(CaptureManyOwner(3, drops))
    assert_equal(drops[], 6)
    var moved = pending^
    _ = moved^
    assert_equal(drops[], 9)
    _ = Capture[Never].args(CaptureManyOwner(1, drops), CaptureManyOwner(2, drops), CaptureManyOwner(3, drops)).run(discard)
    assert_equal(drops[], 12)

    var calls = 0
    def closure(var first: CaptureManyOwner, var second: CaptureManyOwner, var third: CaptureManyOwner) raises CaptureManyOwner {mut calls} -> CaptureManyOwner:
        calls += 1
        if first.value < 0: raise second^
        return third^
    var forwarded = forward[CaptureManyOwner, CaptureManyOwner](closure, CaptureManyOwner(1, drops), CaptureManyOwner(2, drops), CaptureManyOwner(3, drops))
    assert_equal(forwarded._ok().value.value, 3)
    _ = forwarded^
    assert_equal(drops[], 15)
    var refused = forward[CaptureManyOwner, CaptureManyOwner](closure, CaptureManyOwner(-1, drops), CaptureManyOwner(2, drops), CaptureManyOwner(3, drops))
    assert_equal(refused._err().value.value, 2)
    _ = refused^
    assert_equal(drops[], 18)
    assert_equal(calls, 2)

    # Heterogeneous arguments keep their exact positions and ownership.
    def combine(var a: CaptureManyOwner, var b: Int, var c: String, var d: Float64, var e: CaptureManyOwner, var f: Bool, var g: List[Int], var h: CaptureManyOwner) -> CaptureManyOwner:
        a.value += b + c.byte_length() + Int(d) + e.value + Int(f) + len(g) + h.value
        return a^
    var combined = Capture[Never].args(CaptureManyOwner(1, drops), 2, String("abc"), Float64(4), CaptureManyOwner(5, drops), True, List[Int]([0, 0]), CaptureManyOwner(8, drops)).run(combine)
    assert_equal(combined._ok().value.value, 26)
    _ = combined^
    assert_equal(drops[], 21)
    var owner: List[Int] = [3, 7]
    origins(owner)
