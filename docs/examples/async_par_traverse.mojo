"""Run a collection concurrently with par_traverse, beside validation's par_traverse."""
from fp.algebra import par_sequence, par_traverse, par_traverse_n
from fp.callables import OnceUnary
from fp.data import Result, Ok, Err
from fp.effects import Outcome
from fp.effects.async_runtime import IO, run
from fp.functions import pipeline


def value[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    """The program's success value; a failure or cancellation aborts."""
    var success = outcome.take().to_optional()
    return success.take()


def square_later(var value: Int) -> IO[Int, Int]:
    # Each element's IO runs as its own fiber; it cedes once before finishing.
    return IO[NoneType, Int].cede().map(Square(value))


@fieldwise_init
struct Square(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value * self.value


def reject_odd(var value: Int) -> IO[Int, Int]:
    if value % 2:
        return IO[Int, Int].raise_error(value)
    return IO[Int, Int].pure(value)


def positive(value: Int) -> Result[Int, List[String]]:
    if value <= 0:
        var errors: List[String] = [String(value) + " must be positive"]
        return Err(errors^)
    return Ok(value)


def show(label: String, values: List[Int]):
    var text = String(label, ":")
    for value in values:
        text += " " + String(value)
    print(text)


def main() raises:
    # Results keep source order, whichever element finishes first.
    var squares = value(run(par_traverse(List[Int]([1, 2, 3, 4]), square_later)))
    show("squares", squares)

    # At most two elements run at once.
    var bounded = value(run(par_traverse_n(2, List[Int]([5, 6, 7]), square_later)))
    show("bounded", bounded)

    # A list of programs runs the same way.
    var programs = List[IO[Int, Int]]()
    programs.append(IO[Int, Int].pure(10))
    programs.append(IO[Int, Int].pure(20))
    show("sequenced", value(run(par_sequence(programs^))))

    # The first failure stops the rest; every error observed by then is kept,
    # in element order. Here only element 3 fails.
    var failed = run(par_traverse(List[Int]([2, 3, 4]), reject_odd))
    try:
        _ = failed.take().raise_on_err()
    except failure:
        print("failed with:", failure.errors.first())

    # A Result callback selects error-accumulating validation instead: no
    # fibers, and every element's error is collected.
    var checked = pipeline(List[Int]([2, -3, -5])).par_traverse(positive).get()
    try:
        _ = checked^.raise_on_err()
    except errors:
        print("validation errors:", len(errors))
