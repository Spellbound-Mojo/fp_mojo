"""Owner draining: fibers never outlive the fiber that started them."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, Poll, Driver, Clock, Deferred, IORuntimeConfig, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def value_of(var outcome: Outcome[Int, Int]) -> Int:
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return result^._take_ok()
    return -1000 - result^._take_err().errors.first()


@fieldwise_init
struct Mark(OnceUnary):
    var count: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = NoneType

    def call_once(deinit self, var unit: NoneType) -> NoneType:
        self.count[] += 1
        return None


def guarded(cleanups: ArcPointer[Int], entered: Deferred[Int]) -> IO[Int, Int]:
    """Report entry, then wait forever; cleanup suspends once before it records itself."""
    return entered.complete[Int](1).flat_map(Forever(cleanups.copy()))


@fieldwise_init
struct Forever(OnceUnary):
    var cleanups: ArcPointer[Int]
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Bool) -> IO[Int, Int]:
        return IO[Int, Int].never().guarantee(IO[NoneType, Int].cede().map(Mark(self.cleanups^)))


@fieldwise_init
struct Leave(OnceUnary):
    """Drop the handle once the child has entered, then finish."""
    var value: Int
    var entered: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return self.entered.get[Int]().map(Const(self.value))


@fieldwise_init
struct Const(OnceUnary):
    var value: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var ignored: Int) -> Int:
        return self.value


def unjoined_running() raises:
    var cleanups = ArcPointer(0)
    var entered = Deferred[Int]()
    var outcome = run(guarded(cleanups, entered).start().flat_map(Leave(1, entered.copy())))
    check(value_of(outcome^) == 1, "an unjoined child does not change its owner's outcome")
    check(cleanups[] == 1, "the owner canceled and drained its running child")


def unjoined_failed() raises:
    var entered = Deferred[Int]()
    var child = entered.complete[Int](1).flat_map(Raise())
    check(value_of(run(child^.start().flat_map(Leave(1, entered.copy())))) == 1, "an unjoined failure does not fail its owner")


@fieldwise_init
struct Raise(OnceUnary):
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Bool) -> IO[Int, Int]:
        return IO[Int, Int].raise_error(9)


@fieldwise_init
struct Step(OnceUnary):
    var limit: Int
    var steps: ArcPointer[Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        self.steps[] += 1
        if value == self.limit:
            return IO[Int, Int].pure(value)
        return IO[NoneType, Int].cede().flat_map(Next(value, self.limit, self.steps^))


@fieldwise_init
struct Next(OnceUnary):
    var value: Int
    var limit: Int
    var steps: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        return IO[Int, Int].pure(self.value + 1).flat_map(Step(self.limit, self.steps^))


@fieldwise_init
struct Masked(OnceUnary):
    """A region that ignores its Poll and runs a suspending loop to the end."""
    var steps: ArcPointer[Int]
    comptime Arg = Poll[Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var poll: Poll[Int]) -> IO[Int, Int]:
        return IO[Int, Int].pure(0).flat_map(Step(50, self.steps^))


@fieldwise_init
struct Region(OnceUnary):
    var steps: ArcPointer[Int]
    comptime Arg = Bool
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Bool) -> IO[Int, Int]:
        return IO[Int, Int].uncancelable(Masked(self.steps^))


def masked_child() raises:
    var steps = ArcPointer(0)
    var entered = Deferred[Int]()
    var child = entered.complete[Int](1).flat_map(Region(steps.copy()))
    check(value_of(run(child^.start().flat_map(Leave(1, entered.copy())))) == 1, "the owner completes")
    check(steps[] == 51, "a masked child finishes its region before its owner completes")


@fieldwise_init
struct StartGrandchild(OnceUnary):
    var cleanups: ArcPointer[Int]
    comptime Arg = NoneType
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[Int, Int]:
        var entered = Deferred[Int]()
        return guarded(self.cleanups, entered).start().flat_map(Leave(1, entered.copy()))


@fieldwise_init
struct JoinThenRead(OnceUnary):
    var cleanups: ArcPointer[Int]
    var seen: ArcPointer[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(Read(self.cleanups^, self.seen^))


@fieldwise_init
struct Read(OnceUnary):
    var cleanups: ArcPointer[Int]
    var seen: ArcPointer[Int]
    comptime Arg = Outcome[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> Int:
        self.seen[] = self.cleanups[]
        return value_of(outcome^)


def nested_owner() raises:
    var cleanups = ArcPointer(0)
    var seen = ArcPointer(-1)
    var child = IO[NoneType, Int].cede().flat_map(StartGrandchild(cleanups.copy()))
    check(value_of(run(child^.start().flat_map(JoinThenRead(cleanups.copy(), seen.copy())))) == 1, "the join observes the child's value")
    check(seen[] == 1, "a fiber completes only after draining its own children")


@fieldwise_init
struct JoinIt(OnceUnary):
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join().map(Read(ArcPointer(0), ArcPointer(0)))


def cancel_root() raises:
    var cleanups = ArcPointer(0)
    var driver = Driver(guarded(cleanups, Deferred[Int]()).start().flat_map(JoinIt()), CancellationToken(), Clock(), IORuntimeConfig())
    for _ in range(4):
        _ = driver.poll()
    var parked = driver.poll()
    var polls = 0
    driver.request_cancel()
    while not driver.poll().completed:
        polls += 1
        check(polls < 1_000, "a canceled owner drains its children")
    var outcome = driver^.finish()
    check(not parked.completed and parked.quiescent, "an owner joining a waiting child is quiescent")
    check(not outcome, "the owner is canceled while it waits")
    check(cleanups[] == 1, "the child's cleanup ran before the root completed")


@fieldwise_init
struct Second(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var pair: Tuple[Int, Int]) -> Int:
        return pair[0] * 10 + pair[1]


def both_child_host() raises:
    var cleanups = ArcPointer(0)
    var entered = Deferred[Int]()
    var left = guarded(cleanups, entered).start().flat_map(Leave(1, entered.copy()))
    var outcome = run(left^.both(IO[Int, Int].pure(2)).map(Second()))
    check(value_of(outcome^) == 12, "a child of both hosts and drains its own fibers")
    check(cleanups[] == 1, "the pair completed after the nested host drained")


def main() raises:
    unjoined_running()
    unjoined_failed()
    masked_child()
    nested_owner()
    cancel_root()
    both_child_host()
    print("fiber drain: unjoined, failed, masked, nested owners, root cancellation, nested hosts")
