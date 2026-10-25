"""Inferred and explicit break types retain external origins in both entry points."""
from fp.data import ControlFlow, Break, Continue
from fp.iteration import fold_until, iterated
from std.iter import iter
from std.testing import assert_equal

def exercise(first: List[Int], second: List[Int]) raises:
    var initial = Span(first)
    var stopped = Span(second)
    comptime A = type_of(initial)
    comptime B = type_of(stopped)
    def pure(var acc: A, var item: Int) {stopped} -> ControlFlow[B, A]:
        if item == 1: return ControlFlow[B, A](Break(stopped))
        return ControlFlow[B, A](Continue(acc))
    def raising(var acc: A, var item: Int) raises Error {stopped} -> ControlFlow[B, A]:
        if item < 0: raise Error("negative item")
        if item == 1: return ControlFlow[B, A](Break(stopped))
        return ControlFlow[B, A](Continue(acc))

    var inferred = fold_until(pure, initial, iter(range(3)))
    comptime assert type_of(inferred) == ControlFlow[B, A]
    var payload = inferred^.unwrap[Break[B]]().into_payload()
    assert_equal(Pointer(to=payload[0]) == Pointer(to=second[0]), True)

    # F remains the first positional explicit binding; B remains nameable.
    var explicit = fold_until[type_of(pure), B=B](pure, initial, iter(range(3)))
    payload = explicit^.unwrap[Break[B]]().into_payload()
    assert_equal(Pointer(to=payload[0]) == Pointer(to=second[0]), True)
    var raised = fold_until[type_of(raising), B=B](raising, initial, iter(range(3)))
    payload = raised^.unwrap[Break[B]]().into_payload()
    assert_equal(Pointer(to=payload[0]) == Pointer(to=second[0]), True)

    var fluent = iterated(range(3)).fold_until[type_of(pure), B=B](pure, initial)
    payload = fluent^.unwrap[Break[B]]().into_payload()
    assert_equal(Pointer(to=payload[0]) == Pointer(to=second[0]), True)
    var fluent_raising = iterated(range(3)).fold_until[type_of(raising), B=B](raising, initial)
    payload = fluent_raising^.unwrap[Break[B]]().into_payload()
    assert_equal(Pointer(to=payload[0]) == Pointer(to=second[0]), True)

    var empty = fold_until(pure, initial, iter(range(0)))
    var continued = empty^.unwrap[Continue[A]]().into_payload()
    assert_equal(Pointer(to=continued[0]) == Pointer(to=first[0]), True)
    var caught = False
    try: _ = fold_until(raising, initial, iter(range(-1, 0)))
    except error:
        assert_equal(String(error), "negative item")
        caught = True
    assert_equal(caught, True)

def main() raises:
    var first: List[Int] = [11]
    var second: List[Int] = [22]
    exercise(first, second)
