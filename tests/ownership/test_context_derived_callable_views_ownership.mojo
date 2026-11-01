"""Shared chains retain captures and release discarded or unread owned values."""
from fp.functions import pipeline, kleisli
from fp.algebra import ResultFamily
from fp.callables import Unary
from fp.data import Result, Ok, Err
from fp.effects import Reader, run
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true


@fieldwise_init
struct Owner(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


@fieldwise_init
struct Select(Unary):
    var capture: Owner
    comptime Arg = Owner
    comptime Out = Result[Optional[Owner], String]
    def call(self, var arg: Owner) -> Self.Out:
        if arg.value < 0: return Err(String("negative"))
        if arg.value % 2: return Ok(Optional[Owner]())
        arg.value += self.capture.value
        return Ok(Optional(arg^))


@fieldwise_init
struct Expand(Unary):
    var capture: Owner
    comptime Arg = Owner
    comptime Out = Result[List[Owner], String]
    def call(self, var arg: Owner) -> Self.Out:
        if arg.value < 0: return Err(String("negative"))
        arg.value += self.capture.value
        var values: List[Owner] = [arg^]
        return Ok(values^)


def check_owners() raises:
    var captures = ArcPointer(0)
    var payloads = ArcPointer(0)
    var selector = kleisli[ResultFamily[String]](Select(Owner(10, captures)))
    var source: List[Owner] = [Owner(1, payloads), Owner(2, payloads), Owner(3, payloads)]
    var selected = pipeline(source^).traverse_filter(selector).get()
    assert_equal(payloads[], 2)
    assert_equal(selected._ok().value[0].value, 12)
    _ = selected^
    assert_equal(payloads[], 3)
    var bad: List[Owner] = [Owner(2, payloads), Owner(-1, payloads), Owner(4, payloads)]
    assert_true(pipeline(bad^).traverse_filter(selector).get().is_err())
    assert_equal(payloads[], 6)
    assert_equal(captures[], 0)
    _ = selector^
    assert_equal(captures[], 1)
    var expander = kleisli[ResultFamily[String]](Expand(Owner(20, captures)))
    var inputs: List[Owner] = [Owner(1, payloads), Owner(2, payloads)]
    var expanded = pipeline(inputs^).flat_traverse(expander).get()
    assert_equal(expanded._ok().value[1].value, 22)
    assert_equal(payloads[], 6)
    _ = expanded^
    assert_equal(payloads[], 8)
    var discarded: List[Owner] = [Owner(3, payloads), Owner(4, payloads)]
    assert_true(pipeline(discarded^).traverse_void(expander).get().is_ok())
    assert_equal(payloads[], 10)
    var failing: List[Owner] = [Owner(3, payloads), Owner(-4, payloads), Owner(5, payloads)]
    assert_true(pipeline(failing^).traverse_void(expander).get().is_err())
    assert_equal(payloads[], 13)
    assert_equal(captures[], 1)
    _ = expander^
    assert_equal(captures[], 2)


@fieldwise_init
struct Later(Unary):
    var capture: Owner
    comptime Arg = Int
    comptime Out = Reader[Int].Pure[Optional[Int]]
    def call(self, var arg: Int) -> Self.Out:
        return Reader[Int].pure(Optional(arg + self.capture.value))


def check_deferred() raises:
    var drops = ArcPointer(0)
    var chain = kleisli[Reader[Int]](Later(Owner(10, drops)))
    var pending = pipeline(List[Int]([1, 2])).traverse_filter(chain).get()
    assert_equal(drops[], 0)
    assert_equal(run[Reader[Int]](pending^, 0), [11, 12])
    var abandoned = pipeline(List[Int]([3, 4])).traverse_void(chain).get()
    _ = abandoned^
    assert_equal(drops[], 0)
    assert_equal(run[Reader[Int]](chain.call(5), 0).value(), 15)
    _ = chain^
    assert_equal(drops[], 1)


def main() raises:
    check_owners()
    check_deferred()
