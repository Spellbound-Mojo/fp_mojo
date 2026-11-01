"""Bounded concurrent traversal: never more than `limit` live children, and `limit = 1` is `traverse`."""
from std.os import abort
from fp.callables import Unary, OnceUnary
from fp.algebra import traverse, par_traverse_n
from fp.effects import Outcome
from fp.effects.async_runtime import Async
from fp.effects.async_runtime import IO, Ref, Driver, run
from fp.effects.async_runtime.protocols import Machine


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def inc(var value: Int) -> Int:
    return value + 1


def dec(var value: Int) -> Int:
    return value - 1


@fieldwise_init
struct AtLeast(OnceUnary):
    var value: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var high: Int) -> Int:
        return max(high, self.value)


@fieldwise_init
struct RaiseHigh(OnceUnary):
    var high: Ref[Int]
    comptime Arg = Int
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var live: Int) -> IO[NoneType, Int]:
        return self.high.update[Int](AtLeast(live))


@fieldwise_init
struct Then(OnceUnary):
    var next: IO[NoneType, Int]
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        return self.next^


@fieldwise_init
struct Value(OnceUnary):
    var value: Int
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return self.value


def yields(count: Int) -> IO[NoneType, Int]:
    var program = IO[NoneType, Int].pure(None)
    for _ in range(count):
        program = program^.flat_map(Then(IO[NoneType, Int].cede()))
    return program^


@fieldwise_init
struct Tracked(Unary, Copyable):
    """Count itself live in a Ref, record the high-water mark, yield a few times, then leave."""
    var live: Ref[Int]
    var high: Ref[Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[Int, Int]:
        var enter = self.live.update_and_get[Int](inc).flat_map(RaiseHigh(self.high.copy()))
        return enter^.flat_map(Then(yields(index * 7 % 5 + 1))).flat_map(Then(self.live.update[Int](dec))).map(Value(index))


@fieldwise_init
struct Logged(Unary, Copyable):
    """Log the element's start and end; element `failing` fails between them."""
    var log: Ref[List[Int]]
    var failing: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    comptime Error = Never

    def call(self, var index: Int) -> IO[Int, Int]:
        var body = self.log.update[Int](Log(index)).flat_map(Then(IO[NoneType, Int].cede()))
        if index == self.failing:
            return body^.flat_map(Then(IO[NoneType, Int].raise_error(index))).map(Value(index))
        return body^.flat_map(Then(self.log.update[Int](Log(1000 + index)))).map(Value(index))


@fieldwise_init
struct Log(OnceUnary):
    var entry: Int
    comptime Arg = List[Int]
    comptime Out = List[Int]

    def call_once(deinit self, var log: List[Int]) -> List[Int]:
        log.append(self.entry)
        return log^


def indices(n: Int) -> List[Int]:
    var values = List[Int]()
    for index in range(n):
        values.append(index)
    return values^


def get(cell: Ref[Int]) -> Int:
    var outcome = run(cell.get[Int]())
    return outcome.take()._take_ok()


def get_log(cell: Ref[List[Int]]) -> List[Int]:
    var outcome = run(cell.get[Int]())
    return outcome.take()._take_ok()


def step[P: Machine](mut driver: Driver[P]) -> Bool:
    try:
        return driver.poll(1).completed
    except:
        abort("a nonnegative budget is accepted")


def high_water(limit: Int, n: Int):
    var live = Ref[Int](0)
    var high = Ref[Int](0)
    var driver = Driver(par_traverse_n(limit, indices(n), Tracked(live.copy(), high.copy())))
    var most = 0
    while not step(driver):
        var fibers = len(driver.fibers())
        check(fibers <= limit, "diagnostics never show more live children than the limit")
        most = max(most, fibers)
    var outcome = driver^.finish()
    var values = outcome.take()._take_ok()
    check(len(values) == n, "every element completes")
    for index in range(n):
        check(values[index] == index, "results keep source order")
    check(get(high) <= limit and get(high) == min(limit, n), "the Ref high-water mark reaches but never exceeds the limit")
    check(most == min(limit, n), "the limit is used")
    check(get(live) == 0, "every element left")


def outcome_code(var outcome: Outcome[List[Int], Int]) -> String:
    if not outcome:
        return "canceled"
    var result = outcome.take()
    if result.is_ok():
        return String("ok ", len(result^._take_ok()))
    var failure = result^._take_err()
    var line = String("err")
    if failure.canceled:
        line.write(" canceled")
    var errors = failure^.into_errors().into_list()
    for error in errors:
        line.write(" ", error)
    return line


def limit_one_is_traverse(failing: Int):
    var sequential_log = Ref[List[Int]](List[Int]())
    var sequential = outcome_code(run(traverse[Async[Int]](indices(6), Logged(sequential_log.copy(), failing))))
    var bounded_log = Ref[List[Int]](List[Int]())
    var one = outcome_code(run(par_traverse_n(1, indices(6), Logged(bounded_log.copy(), failing))))
    check(sequential == one, String("limit = 1 matches traverse in outcome: ", sequential, " vs ", one))
    var expected = get_log(sequential_log)
    var seen = get_log(bounded_log)
    check(len(expected) == len(seen), "limit = 1 runs the same effects")
    for index in range(len(seen)):
        check(expected[index] == seen[index], "limit = 1 runs effects in traverse's order")


def main():
    high_water(4, 50)
    high_water(1, 10)
    high_water(64, 10)
    high_water(64, 300)
    limit_one_is_traverse(-1)
    limit_one_is_traverse(3)
    print("par_traverse bounded: at most limit live children by Ref and diagnostics; limit = 1 matches traverse")
