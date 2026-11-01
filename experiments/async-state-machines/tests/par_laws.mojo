"""AsyncPar laws on outcomes: the Applicative laws, and par_traverse with pure callbacks equals traverse.

Operands succeed or fail at once, and failures combine their errors in
operand order, as `both` does. Outcomes are compared by success value and
ordered errors. A failure's cancellation mark is left out: it records whether
a sibling was stopped mid-flight, and a nested combination takes more steps
to finish than an operand, so the mark depends on the association, as it
does for nested `both`.
"""
from std.os import abort
from fp.callables import Binary, Unary
from fp.callables._identity import Identity
from fp.algebra import map, map2, pure, traverse, sequence, par_traverse, par_sequence
from fp.effects import Outcome
from fp.effects.async_runtime import AsyncPar, Async
from fp.effects.async_runtime import IO, run

comptime Par = AsyncPar[Int]


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def code(var outcome: Outcome[Int, Int]) -> String:
    if not outcome:
        return "canceled"
    var result = outcome.take()
    if result.is_ok():
        return String("ok ", result^._take_ok())
    var failure = result^._take_err()
    var line = String("err")
    for error in failure^.into_errors().into_list():
        line.write(" ", error)
    return line


def list_code(var outcome: Outcome[List[Int], Int]) -> String:
    if not outcome:
        return "canceled"
    var result = outcome.take()
    if result.is_ok():
        var line = String("ok")
        for value in result^._take_ok():
            line.write(" ", value)
        return line
    var failure = result^._take_err()
    var line = String("err")
    for error in failure^.into_errors().into_list():
        line.write(" ", error)
    return line


@fieldwise_init
struct Add(Binary, Copyable):
    comptime First = Int
    comptime Second = Int
    comptime Out = Int
    comptime Error = Never

    def call(self, var left: Int, var right: Int) -> Int:
        return left + right


@fieldwise_init
struct Second(Binary, Copyable):
    comptime First = NoneType
    comptime Second = Int
    comptime Out = Int
    comptime Error = Never

    def call(self, var left: NoneType, var right: Int) -> Int:
        return right


@fieldwise_init
struct First(Binary, Copyable):
    comptime First = Int
    comptime Second = NoneType
    comptime Out = Int
    comptime Error = Never

    def call(self, var left: Int, var right: NoneType) -> Int:
        return left


def operand(fails: Bool, value: Int) -> IO[Int, Int]:
    if fails:
        return IO[Int, Int].raise_error(value)
    return IO[Int, Int].pure(value)


def applicative_laws():
    for mask in range(8):
        var a = Bool(mask & 1)
        var b = Bool(mask & 2)
        var c = Bool(mask & 4)
        var left = code(run(map2[Par](Add(), map2[Par](Add(), operand(a, 1), operand(b, 20)), operand(c, 300))))
        var right = code(run(map2[Par](Add(), operand(a, 1), map2[Par](Add(), operand(b, 20), operand(c, 300)))))
        check(left == right, String("associativity: ", left, " vs ", right))
        var unit = IO[NoneType, Int].pure(None)
        check(code(run(map2[Par](Second(), unit^, operand(a, 1)))) == code(run(operand(a, 1))), "left identity")
        var unit_right = IO[NoneType, Int].pure(None)
        check(code(run(map2[Par](First(), operand(a, 1), unit_right^))) == code(run(operand(a, 1))), "right identity")
        check(code(run(map[Par](operand(a, 1), Identity[Int]()))) == code(run(operand(a, 1))), "functor identity")
    check(code(run(map2[Par](Add(), pure[Par](4), pure[Par](5)))) == "ok 9", "homomorphism")
    var errors = code(run(map2[Par](Add(), map2[Par](Add(), operand(True, 1), operand(True, 20)), operand(True, 300))))
    check(errors == "err 1 20 300", String("every error, in operand order: ", errors))


@fieldwise_init
struct Pure(Unary, Copyable):
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var value: Int) -> IO[Int, Int]:
        return IO[Int, Int].pure(value * value)


def indices(n: Int) -> List[Int]:
    var values = List[Int]()
    for index in range(n):
        values.append(index)
    return values^


def traverse_law():
    for n in range(0, 70, 23):
        var concurrent = list_code(run(par_traverse(indices(n), Pure())))
        var sequential = list_code(run(traverse[Async[Int]](indices(n), Pure())))
        check(concurrent == sequential, "par_traverse with pure callbacks equals traverse")
        var programs = List[IO[Int, Int]]()
        var expected = List[IO[Int, Int]]()
        for index in range(n):
            programs.append(IO[Int, Int].pure(index))
            expected.append(IO[Int, Int].pure(index))
        check(list_code(run(par_sequence(programs^))) == list_code(run(sequence[Async[Int]](expected^))), "par_sequence of pure programs equals sequence")


def main():
    applicative_laws()
    traverse_law()
    print("AsyncPar laws: associativity, identities and homomorphism on outcomes; pure par_traverse equals traverse")
