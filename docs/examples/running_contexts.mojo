"""Run parts of a program on other execution contexts, then resume where it was."""
from fp.callables import OnceUnary
from fp.effects import Outcome
from fp.effects.async_runtime import IO, Background, BlockingPool, ExecutionContext, Fiber, IORuntimeConfig, Profile, Runtime, run
from std.testing import assert_equal

comptime Context = Optional[ExecutionContext]


def named(var context: Context) -> String:
    if context:
        return String(context.value())
    return "none"


def where() -> IO[String, Int]:
    # Reads the context running the current program when the IO is reached.
    return IO[Context, Int].execution_context().map(named)


@fieldwise_init
struct ThenHere(OnceUnary):
    """After a region reports where it ran, report where its caller resumed."""
    comptime Arg = String
    comptime Out = IO[String, Int]

    def call_once(deinit self, var there: String) -> IO[String, Int]:
        return where().map(Prefix(there^))


@fieldwise_init
struct Prefix(OnceUnary):
    var there: String
    comptime Arg = String
    comptime Out = String

    def call_once(deinit self, var here: String) -> String:
        return self.there + ", then " + here


def sum_to(n: Int) -> Int:
    # Stands in for CPU-bound work.
    var total = 0
    for value in range(1, n + 1):
        total += value
    return total


@fieldwise_init
struct Add(OnceUnary):
    var mine: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var theirs: Int) -> Int:
        return self.mine + theirs


@fieldwise_init
struct JoinAndAdd(OnceUnary):
    """Join the fiber whose work runs on the runtime, and add its value to the caller's."""
    var fiber: Fiber[Int, Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var mine: Int) -> IO[Int, Int]:
        return self.fiber^.join_with(IO[Int, Int].pure(-1)).map(Add(mine))


@fieldwise_init
struct Meanwhile(OnceUnary):
    """Compute the caller's part while the started fiber runs elsewhere."""
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return IO[Int, Int].pure(100).map(sum_to).flat_map(JoinAndAdd(fiber^))


def joined(var outcome: Outcome[String, Int]) -> String:
    if not outcome:
        return "canceled"
    return outcome.take().get_or("failed")


def join_where(handle: Background[String, Int]) -> IO[String, Int]:
    # The body borrows the handle; join takes the fiber's outcome once.
    return handle.join().map(joined)


def value[T: Movable & Deinitable](var outcome: Outcome[T, Int], var fallback: T) -> T:
    # A canceled program has no outcome; a failed one keeps its errors.
    if not outcome:
        return fallback^
    return outcome.take().get_or(fallback^)


def main() raises:
    var config = IORuntimeConfig()
    config.profile = Profile.work_stealing(2)
    var compute = Runtime(config)
    var files = BlockingPool(max_workers=1)

    print("free run:", value(run(where()), "?"))
    print("runtime.run:", value(compute.run(where()), "?"))
    print("eval_on(compute):", value(run(where().eval_on(compute)), "?"))
    print("eval_on(files):", value(run(where().eval_on(files).flat_map(ThenHere())), "?"))
    print("nested:", value(compute.run(where().eval_on(files).flat_map(ThenHere())), "?"))

    # start_on starts an ordinary child of the caller whose work runs on compute.
    var split = IO[Int, Int].pure(1000).map(sum_to).start_on(compute).flat_map(Meanwhile())
    var total = value(run(split^), -1)
    assert_equal(total, 505550)
    print("start_on:", total)

    # background_on runs a fiber on files for the length of the resource's use.
    var seen = value(run(where().background_on(files).use(join_where)), "?")
    assert_equal(seen, "blocking_pool")
    print("background_on:", seen)
