"""Concurrent on Async: Ref and Deferred through the generic entry points, and Ref's own operations."""
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import (Outcome, CancellationToken, make_ref, make_deferred, get_ref, set_ref, update_ref, modify_ref,
    complete_deferred, get_deferred)
from fp.effects.async_runtime import IO, Async, Ref, Deferred, Driver, Clock, IORuntimeConfig, Progress, run
from fp.effects.async_runtime.protocols import Machine

comptime A = Async[Int]


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    if not outcome or not outcome.value().is_ok():
        abort("expected a success")
    return outcome.take()._take_ok()


def bump(var value: Int) -> Int:
    return value + 1


def tenfold(var value: Int) -> Tuple[Int, String]:
    return (value * 10, String("was ") + String(value))


@fieldwise_init
struct SetThenGet(OnceUnary):
    comptime Arg = Ref[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var cell: Ref[Int]) -> IO[Int, Int]:
        return set_ref[A](cell, 5).flat_map(ModifyAfter(cell.copy()))


@fieldwise_init
struct ModifyAfter(OnceUnary):
    var cell: Ref[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return modify_ref[A, String](self.cell, tenfold).flat_map(ReadAfter(self.cell.copy()))


@fieldwise_init
struct ReadAfter(OnceUnary):
    var cell: Ref[Int]
    comptime Arg = String
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var message: String) -> IO[Int, Int]:
        check(message == "was 5", "modify_ref produces its result from the previous state")
        return get_ref[A, Int](self.cell)


def generic_reads_and_writes() raises:
    check(value_of(run(make_ref[A](1).flat_map(SetThenGet()))) == 50, "set, modify, then get through Concurrent")


@fieldwise_init
struct Bumps(OnceUnary):
    """Bump the cell a number of times, yielding between bumps."""
    var cell: Ref[Int]
    var left: Int
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        if self.left == 0:
            return IO[NoneType, Int].pure(None)
        var next = Bumps(self.cell.copy(), self.left - 1)
        return update_ref[A](self.cell, bump).flat_map(CedeThen(next^))


@fieldwise_init
struct CedeThen(OnceUnary):
    var next: Bumps
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        return IO[NoneType, Int].cede().flat_map(self.next^)


def bumps(cell: Ref[Int], count: Int) -> IO[NoneType, Int]:
    return IO[NoneType, Int].pure(None).flat_map(Bumps(cell.copy(), count))


@fieldwise_init
struct Contend(OnceUnary):
    """Four fibers bump one cell with yields between bumps; then read it."""
    comptime Arg = Ref[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var cell: Ref[Int]) -> IO[Int, Int]:
        var pairs = bumps(cell, 25).both(bumps(cell, 25)).both(bumps(cell, 25).both(bumps(cell, 25)))
        return pairs^.flat_map(ReadCell[Tuple[Tuple[NoneType, NoneType], Tuple[NoneType, NoneType]]](cell.copy()))


@fieldwise_init
struct ReadCell[X: Movable & Deinitable](OnceUnary):
    var cell: Ref[Int]
    comptime Arg = Self.X
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var ignored: Self.X) -> IO[Int, Int]:
        return get_ref[A, Int](self.cell)


def atomic_updates() raises:
    check(value_of(run(make_ref[A](0).flat_map(Contend()))) == 100, "updates from interleaved fibers are all kept")


@fieldwise_init
struct Sum(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var pair: Tuple[Int, Int]) -> Int:
        return pair[0] + pair[1]


@fieldwise_init
struct CompleteTwice(OnceUnary):
    var deferred: Deferred[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return complete_deferred[A](self.deferred, 7).flat_map(CompleteAgain(self.deferred.copy()))


@fieldwise_init
struct CompleteAgain(OnceUnary):
    var deferred: Deferred[Int]
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Bool) -> IO[Int, Int]:
        check(first, "the first completion wins")
        return complete_deferred[A](self.deferred, 9).map(Code())


@fieldwise_init
struct Code(OnceUnary):
    comptime Arg = Bool
    comptime Out = Int

    def call_once(deinit self, var second: Bool) -> Int:
        return 0 if second else 1


@fieldwise_init
struct ReadersAndWriter(OnceUnary):
    """Two readers wait; a writer yields, then completes twice."""
    comptime Arg = Deferred[Int]
    comptime Out = IO[Tuple[Int, Int], Int]

    def call_once(deinit self, var deferred: Deferred[Int]) -> IO[Tuple[Int, Int], Int]:
        var readers = get_deferred[A, Int](deferred).both(get_deferred[A, Int](deferred)).map(Sum())
        var writer = IO[NoneType, Int].cede().flat_map(CompleteTwice(deferred.copy()))
        return readers^.both(writer^)


def deferred_values() raises:
    var result = value_of(run(make_deferred[A, Int]().flat_map(ReadersAndWriter())))
    check(result[0] == 14, "every waiting reader receives the value")
    check(result[1] == 1, "a second completion loses and leaves the value")


@fieldwise_init
struct BumpThenGet(OnceUnary):
    comptime Arg = Ref[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var cell: Ref[Int]) -> IO[Int, Int]:
        return update_ref[A](cell, bump).flat_map(ReadCell[NoneType](cell.copy()))


@fieldwise_init
struct Double(OnceUnary):
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return value * 2


@fieldwise_init
struct Halve(OnceUnary):
    comptime Arg = Int
    comptime Out = Tuple[Int, Int]

    def call_once(deinit self, var value: Int) -> Tuple[Int, Int]:
        return (value // 2, value)


@fieldwise_init
struct HalveAfter(OnceUnary):
    var cell: Ref[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return modify_ref[A, Int](self.cell, Halve())


@fieldwise_init
struct DoubleThenHalve(OnceUnary):
    comptime Arg = Ref[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var cell: Ref[Int]) -> IO[Int, Int]:
        return update_ref[A](cell, Double()).flat_map(HalveAfter(cell.copy()))


def library_callables() raises:
    check(value_of(run(make_ref[A](21).flat_map(DoubleThenHalve()))) == 42, "update_ref and modify_ref take library callables")


def counter() -> IO[Int, Int]:
    return make_ref[A](0).flat_map(BumpThenGet())


def fresh_state() raises:
    check(value_of(run(counter())) == 1 and value_of(run(counter())) == 1, "each run of a program creates fresh state")


@fieldwise_init
struct Box(Movable):
    """Move-only state."""
    var value: Int


def take_box(var box: Box) -> Tuple[Box, Int]:
    var value = box.value
    return (Box(value + 1), value)


def box_value(box: Box) -> Int:
    return box.value


def negate(value: Int) -> Int:
    return -value


def ref_operations() raises:
    var cell = Ref(5)
    check(value_of(run(cell.get_and_update[Int](bump))) == 5, "get_and_update yields the previous state")
    check(value_of(run(cell.update_and_get[Int](bump))) == 7, "update_and_get yields the next state")
    check(value_of(run(cell.get_and_set[Int](100))) == 7, "get_and_set transfers the previous state")
    check(value_of(run(cell.get[Int]())) == 100, "get copies the state")
    check(value_of(run(cell.inspect[Int](negate))) == -100, "inspect borrows register-passable state")
    var boxed = Ref(Box(1))
    check(value_of(run(boxed.modify[Int, Int](take_box))) == 1, "modify consumes move-only state")
    check(value_of(run(boxed.inspect[Int](box_value))) == 2, "inspect borrows move-only state")
    _ = run(boxed.set[Int](Box(40)))
    check(value_of(run(boxed.inspect[Int](box_value))) == 40, "set replaces move-only state")


def step[P: Machine](mut driver: Driver[P], budget: Int) -> Progress:
    try:
        return driver.poll(budget)
    except:
        abort("a nonnegative budget is accepted")


def suspension() raises:
    var deferred = Deferred[Int]()
    var driver = Driver(get_deferred[A, Int](deferred), CancellationToken(), Clock(), IORuntimeConfig())
    var waiting = step(driver, 8)
    check(not waiting.completed and not waiting.runnable and waiting.quiescent, "a waiting read parks")
    var idle = step(driver, 8)
    check(idle.transitions == 0 and idle.polls == 0, "a parked read spends no work until woken")
    check(value_of(run(complete_deferred[A](deferred, 11))), "the host completes the value from another root")
    while True:
        var progress = step(driver, 8)
        if progress.completed:
            break
    check(value_of(driver^.finish()) == 11, "completion wakes the parked read")


def main() raises:
    generic_reads_and_writes()
    atomic_updates()
    deferred_values()
    fresh_state()
    library_callables()
    ref_operations()
    suspension()
    print("capability concurrent: generic Ref and Deferred, atomic interleaved updates, fresh state per run, Ref operations, parked reads")
