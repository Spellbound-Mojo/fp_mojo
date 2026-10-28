"""Shared admission adds no bound-value copies; native invocation still copies."""
from fp.functions import pipeline, partial
from fp.effects import Reader, run
from algebra_support.result_ownership import Trace, trace
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Bound(Copyable):
    var value: Int
    var ledger: ArcPointer[Trace]
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.ledger = copy.ledger
        self.ledger[].factories += 1
    def __deinit__(deinit self): self.ledger[].drops[0] += 1


def add(var bound: Bound, value: Int) -> Int:
    bound.ledger[].calls += 1
    return bound.value + value


def copies() raises:
    var ledger = trace()
    var source = Bound(10, ledger)
    var callback = partial(add, source)
    assert_equal(ledger[].factories, 1)
    assert_equal(ledger[].drops[0], 0)
    assert_equal(pipeline(List[Int]([1, 2])).map(callback).get(), [11, 12])
    assert_equal(ledger[].factories, 3)
    assert_equal(ledger[].drops[0], 2)
    assert_equal(pipeline(Optional(3)).map(callback).get_or(0), 13)
    assert_equal(ledger[].factories, 4)
    assert_equal(ledger[].drops[0], 3)
    var pending = pipeline[Reader[Int]](Reader[Int].pure(4)).map(callback).get()
    assert_equal(ledger[].factories, 4)
    assert_equal(run[Reader[Int]](pending^, 0), 14)
    assert_equal(ledger[].factories, 5)
    assert_equal(ledger[].drops[0], 4)
    var abandoned = pipeline[Reader[Int]](Reader[Int].pure(5)).map(callback).get()
    _ = abandoned^
    assert_equal(ledger[].factories, 5)
    var owned = pipeline[Reader[Int]](Reader[Int].pure(6)).map(callback^).get()
    assert_equal(run[Reader[Int]](owned^, 0), 16)
    assert_equal(ledger[].factories, 6)
    assert_equal(ledger[].drops[0], 6)
    assert_equal(ledger[].calls, 5)
    _ = source^
    assert_equal(ledger[].drops[0], 7)


def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var prefix: View, value: Int) -> View: return prefix
    var callback = partial(keep, view)
    var selected = pipeline(1).then(callback).get()
    assert_true(Pointer(to=selected[0]) == Pointer(to=owner[0]))
    var pending = pipeline[Reader[Int]](Reader[Int].pure(2)).map(callback).get()
    var result = run[Reader[Int]](pending^, 0)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))


def outside(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var prefix: View, value: Int) -> View: return prefix
    var callback = partial(keep, view)
    return pipeline(1).then(callback).get()


def main() raises:
    copies()
    origins([7, 11])
    var owner: List[Int] = [13, 17]
    var retained = outside(owner)
    assert_true(Pointer(to=retained[1]) == Pointer(to=owner[1]))
