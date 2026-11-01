"""Fluent and iterator selection: an IO callback selects AsyncPar, a Result callback keeps Validation.

Each IO element sleeps 50 ms on TestControl's virtual clock, so a concurrent
traversal completes at virtual 50 ms; a sequential one would take 50 ms per
element. Async[E].Par names AsyncPar[E].
"""
from std.os import abort
from fp.callables import OnceUnary
from fp.algebra import par_traverse_void_n
from fp.functions import pipeline
from fp.iteration import iterated, par_traverse as iter_par_traverse, par_sequence as iter_par_sequence, par_traverse_void
from fp.data import Result, Ok, Err
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Async, AsyncPar, Duration, Instant, TestControl
from fp.effects.async_runtime.protocols import Machine


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def ms(value: Int) -> Duration:
    try:
        return Duration.milliseconds(value)
    except:
        abort("a valid duration")


@fieldwise_init
struct Value(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


def nap(var index: Int) -> IO[Int, Int]:
    return IO[NoneType, Int].sleep(ms(50)).map(Value(index + 100))


def napping(value: Int) -> IO[Int, Int]:
    return IO[NoneType, Int].sleep(ms(50)).map(Value(value))


def validate(var index: Int) -> Result[Int, List[String]]:
    if index % 2:
        var errors: List[String] = [String("odd ", index)]
        return Err(errors^)
    return Ok(index)


def add3(var a: Int, var b: Int, var c: Int) -> Int:
    return a + b + c


def indices(n: Int) -> List[Int]:
    var values = List[Int]()
    for index in range(n):
        values.append(index)
    return values^


def at_50ms[P: Machine](var program: P) -> Outcome[P.Value, P.Error]:
    var control = TestControl(program^)
    control.tick_all()
    check(control.is_completed(), "the program completes")
    check(control.now().since(Instant()).to_nanoseconds() == 50_000_000, "concurrent elements finish together at virtual 50 ms")
    return control^.results()


def ordered(var outcome: Outcome[List[Int], Int], n: Int, offset: Int):
    check(Bool(outcome) and outcome.value().is_ok(), "success")
    var values = outcome.take()._take_ok()
    check(len(values) == n, "one value per element")
    for index in range(n):
        check(values[index] == index + offset, "source order")


def programs(n: Int) -> List[IO[Int, Int]]:
    var values = List[IO[Int, Int]]()
    for index in range(n):
        values.append(napping(index))
    return values^


def main():
    comptime assert Async[Int].Par == AsyncPar[Int], "Async[E].Par is AsyncPar[E]"
    ordered(at_50ms(pipeline(indices(10)).par_traverse(nap).get()), 10, 100)
    ordered(at_50ms(pipeline(programs(10)).par_sequence().get()), 10, 0)
    ordered(at_50ms(iterated(indices(10)).par_traverse(nap)), 10, 100)
    ordered(at_50ms(iterated(programs(10)).par_sequence()), 10, 0)
    ordered(at_50ms(iter_par_traverse(indices(10), nap)), 10, 100)
    ordered(at_50ms(iter_par_sequence(programs(10))), 10, 0)
    var voided = at_50ms(par_traverse_void(indices(10), nap))
    check(Bool(voided) and voided.value().is_ok(), "par_traverse_void runs every element")
    var bounded = at_50ms(par_traverse_void_n(10, indices(10), nap))
    check(Bool(bounded) and bounded.value().is_ok(), "par_traverse_void_n runs every element")
    var mapped = at_50ms(pipeline(napping(1)).par_map_n((napping(20), napping(300)), add3).get())
    check(mapped.take()._take_ok() == 321, "par_map_n combines concurrent IO operands")
    var product = at_50ms(pipeline(napping(1)).par_product_n((napping(2),)).get())
    var pair = product.take()._take_ok()
    check(pair[0] == 1 and pair[1] == 2, "par_product_n pairs concurrent IO operands")
    # A Result callback keeps ValidationFamily: every error accumulates.
    var validated = pipeline(indices(4)).par_traverse(validate).get()
    check(validated.is_err() and len(validated._err().value) == 2, "a Result callback still accumulates errors")
    var iter_validated = iterated(indices(4)).par_traverse(validate)
    check(iter_validated.is_err() and len(iter_validated._err().value) == 2, "Iter keeps Validation for Result callbacks")
    print("par fluent: IO callbacks select AsyncPar on Pipeline, Iter and fp.iteration; Result keeps Validation")
