"""A borrowed receiver retains its capture; an explicit move transfers it."""
from fp.functions import pipeline, kleisli
from fp.algebra import OptionalFamily
from fp.callables import Unary
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Owner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct Keep(Unary):
    var capture: Owner
    comptime Arg = Owner
    comptime Out = Optional[Owner]
    def call(self, var arg: Owner) -> Self.Out:
        arg.value += self.capture.value
        return Optional(arg^)


@fieldwise_init
struct Add(Unary):
    var capture: Owner
    comptime Arg = Int
    comptime Out = Optional[Int]
    def call(self, var arg: Int) -> Self.Out:
        return Optional(arg + self.capture.value)


def check_payloads() raises:
    var captures = ArcPointer(0)
    var payloads = ArcPointer(0)
    var chain = kleisli[OptionalFamily](Keep(Owner(10, captures)))
    var mapped_input: List[Owner] = [Owner(1, payloads)]
    var mapped = pipeline(mapped_input^).map(chain).get()
    assert_equal(mapped[0].value().value, 11)
    assert_equal(payloads[], 0)
    _ = mapped^
    assert_equal(payloads[], 1)
    var filtered_input: List[Owner] = [Owner(2, payloads)]
    var filtered = pipeline(filtered_input^).filter_map(chain).get()
    assert_equal(filtered[0].value, 12)
    _ = filtered^
    assert_equal(payloads[], 2)
    var traversed_input: List[Owner] = [Owner(3, payloads)]
    var traversed = pipeline(traversed_input^).traverse(chain).get()
    assert_equal(traversed.value()[0].value, 13)
    _ = traversed^
    assert_equal(payloads[], 3)
    assert_equal(captures[], 0)
    _ = chain^
    assert_equal(captures[], 1)


def check_deferred_borrow() raises:
    var drops = ArcPointer(0)
    var chain = kleisli[OptionalFamily](Add(Owner(10, drops)))
    var pending = pipeline[Reader[Int]](Reader[Int].pure(3)).map(chain).get()
    assert_equal(drops[], 0)
    assert_equal(run[Reader[Int]](pending^, 0).value(), 13)
    assert_equal(drops[], 0)
    var abandoned = pipeline[Reader[Int]](Reader[Int].pure(4)).map(chain).get()
    _ = abandoned^
    assert_equal(drops[], 0)
    assert_equal(chain.call(5).value(), 15)
    _ = chain^
    assert_equal(drops[], 1)


def check_deferred_move() raises:
    var drops = ArcPointer(0)
    var chain = kleisli[OptionalFamily](Add(Owner(10, drops)))
    var pending = pipeline[Reader[Int]](Reader[Int].pure(3)).map(chain^).get()
    assert_equal(drops[], 0)
    assert_equal(run[Reader[Int]](pending^, 0).value(), 13)
    assert_equal(drops[], 1)
    var other = kleisli[OptionalFamily](Add(Owner(20, drops)))
    var abandoned = pipeline[Reader[Int]](Reader[Int].pure(4)).map(other^).get()
    assert_equal(drops[], 1)
    _ = abandoned^
    assert_equal(drops[], 2)


@fieldwise_init
struct AddLater(Unary):
    var capture: Owner
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Int]
    def call(self, var arg: Int) -> Self.Out:
        return Reader[Int].pure(arg + self.capture.value)


def check_traversal_borrow() raises:
    var drops = ArcPointer(0)
    var chain = kleisli[Reader[Int]](AddLater(Owner(10, drops)))
    var pending = pipeline(List[Int]([1, 2])).traverse(chain).get()
    assert_equal(drops[], 0)
    assert_equal(run[Reader[Int]](pending^, 0), [11, 12])
    assert_equal(drops[], 0)
    var abandoned = pipeline(List[Int]([3, 4])).traverse(chain).get()
    _ = abandoned^
    assert_equal(drops[], 0)
    _ = chain^
    assert_equal(drops[], 1)


def main() raises:
    check_traversal_borrow()
    check_payloads()
    check_deferred_borrow()
    check_deferred_move()
