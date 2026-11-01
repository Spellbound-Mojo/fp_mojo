"""Move-only native captures survive reuse, deferred borrows and explicit moves."""
from fp.functions import pipeline, as_unary
from fp.effects import Reader, run
from fp.iteration import iterated
from algebra_support.result_ownership import Token, trace
from std.testing import assert_equal, assert_true


def captures() raises:
    var ledger = trace()
    var token = Token(1, ledger)
    def captured(var value: Int) {var token^} -> Int:
        token.trace[].calls += 1
        return value + token.id
    var callback = as_unary(captured^)
    comptime assert not conforms_to(type_of(callback), Copyable)
    assert_equal(pipeline(Optional(10)).map(callback).get_or(0), 11)
    assert_equal(pipeline[List[Int]]([1, 2]).map(callback).get(), [2, 3])
    var pending = pipeline[Reader[Int]](Reader[Int].pure(10)).map(callback).get()
    assert_equal(ledger[].calls, 3)
    assert_equal(ledger[].drops[1], 0)
    assert_equal(run[Reader[Int]](pending^, 0), 11)
    var abandoned = pipeline[Reader[Int]](Reader[Int].pure(10)).map(callback).get()
    _ = abandoned^
    assert_equal(ledger[].calls, 4)
    assert_equal(ledger[].drops[1], 0)
    var lazy = iterated(List[Int]([3, 4])).map(callback)
    assert_equal(ledger[].calls, 4)
    assert_equal(lazy^.collect_list(), [4, 5])
    var discarded = iterated(List[Int]([5])).map(callback)
    _ = discarded^
    assert_equal(ledger[].calls, 6)
    assert_equal(ledger[].drops[1], 0)
    var owned = pipeline[Reader[Int]](Reader[Int].pure(10)).map(callback^).get()
    assert_equal(run[Reader[Int]](owned^, 0), 11)
    assert_equal(ledger[].calls, 7)
    assert_equal(ledger[].drops[1], 1)


def origins(owner: List[Int]) raises:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var value: Int) {view} -> View: return view
    var callback = as_unary(keep)
    var selected = pipeline(1).then(callback).get()
    assert_true(Pointer(to=selected[0]) == Pointer(to=owner[0]))
    var pending = pipeline[Reader[Int]](Reader[Int].pure(2)).map(callback).get()
    var result = run[Reader[Int]](pending^, 0)
    assert_true(Pointer(to=result[1]) == Pointer(to=owner[1]))


def outside(owner: List[Int]) -> Span[Int, origin_of(owner)]:
    var view = Span(owner)
    comptime View = type_of(view)
    def keep(var value: Int) {view} -> View: return view
    var callback = as_unary(keep)
    return pipeline(1).then(callback).get()


def temporary() raises:
    var ledger = trace()
    var token = Token(2, ledger)
    def captured(var value: Int) {var token^} -> Int:
        token.trace[].calls += 1
        return value + token.id
    var pending = pipeline[Reader[Int]](Reader[Int].pure(3)).map(as_unary(captured^)).get()
    assert_equal(ledger[].drops[2], 0)
    assert_equal(run[Reader[Int]](pending^, 0), 5)
    assert_equal(ledger[].calls, 1)
    assert_equal(ledger[].drops[2], 1)


def main() raises:
    captures()
    temporary()
    origins([7, 11])
    var owner: List[Int] = [13, 17]
    var retained = outside(owner)
    assert_true(Pointer(to=retained[1]) == Pointer(to=owner[1]))
