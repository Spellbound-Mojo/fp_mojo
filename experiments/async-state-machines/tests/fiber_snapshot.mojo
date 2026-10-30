"""Driver.fibers: a bounded view of the root's live fibers, their owners and status."""
from std.os import abort
from fp.callables import OnceUnary
from fp.effects import CancellationToken, Outcome
from fp.effects.async_runtime import IO, Fiber, FiberInfo, FiberStatus, Driver, Clock, Deferred, IORuntimeConfig, run
from fp.effects.async_runtime.protocols import Machine


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def settle[P: Machine](mut driver: Driver[P]):
    """Poll until nothing is runnable."""
    while True:
        var progress = driver.poll()
        if progress.completed or not progress.runnable:
            return


def step[P: Machine](mut driver: Driver[P]):
    """One root poll, without raising while the driver is live."""
    try:
        _ = driver.poll(1)
    except:
        abort("a nonnegative budget is accepted")


def fire(cell: Deferred[Int]):
    _ = run(cell.complete[Int](1))


@fieldwise_init
struct Drop(OnceUnary):
    comptime Arg = Int
    comptime Out = NoneType

    def call_once(deinit self, var ignored: Int) -> NoneType:
        return None


@fieldwise_init
struct ThenWait[T: Movable & Deinitable](OnceUnary):
    """Keep a started fiber's handle, wait for a cell, then drop the handle."""
    var cell: Deferred[Int]
    comptime Arg = Fiber[Self.T, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Self.T, Int]) -> IO[Int, Int]:
        return self.cell.get[Int]()


def described(fibers: List[FiberInfo]) -> String:
    var line = String()
    for index in range(len(fibers)):
        if index:
            line.write(", ")
        line.write(fibers[index].index, "<-", fibers[index].owner, " ", fibers[index].status)
    return line


def owners_and_status() raises:
    var proceed = Deferred[Int]()
    var gate = Deferred[Int]()
    var finish = Deferred[Int]()
    # B waits forever; its masked cleanup waits for the gate.
    var grandchild = IO[Int, Int].never().guarantee(gate.get[Int]().map(Drop()))
    # A starts B, then waits for proceed; finishing it cancels and drains B.
    var child = grandchild^.start().flat_map(ThenWait[Int](proceed.copy()))
    var driver = Driver(child^.start().flat_map(ThenWait[Int](finish.copy())), CancellationToken(), Clock(), IORuntimeConfig())
    check(len(driver.fibers()) == 0, "nothing is listed before the root enters")
    settle(driver)
    var parked = driver.fibers()
    check(described(parked) == "1<-0 suspended, 2<-1 suspended", "parked fibers list their owners: " + described(parked))
    fire(proceed)
    settle(driver)
    var draining = driver.fibers()
    check(described(draining) == "1<-0 draining, 2<-1 suspended", "a finished owner drains its child: " + described(draining))
    check(draining[0].status == FiberStatus.draining() and draining[0].status != FiberStatus.runnable(), "statuses compare")
    fire(gate)
    settle(driver)
    check(len(driver.fibers()) == 0, "completed fibers leave the view")
    fire(finish)
    while not driver.poll().completed:
        pass
    check(len(driver.fibers()) == 0, "a completed root lists nothing")
    var outcome = driver^.finish()
    check(Bool(outcome) and outcome.value().is_ok(), "the root completes")


def runnable_before_first_poll() raises:
    var driver = Driver(IO[Int, Int].pure(5).start().flat_map(ThenWait[Int](Deferred[Int]())), CancellationToken(), Clock(), IORuntimeConfig(1, 1))
    var seen = False
    for _ in range(4):
        step(driver)
        var fibers = driver.fibers()
        if len(fibers) and fibers[0].status == FiberStatus.runnable():
            seen = True
    check(seen, "an admitted fiber is runnable before its first poll")
    driver.request_cancel()
    while not driver.poll().completed:
        pass
    _ = driver^.finish()


@fieldwise_init
struct One(OnceUnary):
    var cell: Deferred[Int]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return self.cell.get[Int]()


@fieldwise_init
struct Sum(OnceUnary):
    comptime Arg = Tuple[Int, Int]
    comptime Out = Int

    def call_once(deinit self, var pair: Tuple[Int, Int]) -> Int:
        return pair[0] + pair[1]


def nested_hosts_not_listed() raises:
    # The sides of both are fibers of the root, so a fiber one of them starts
    # is listed, owned by that side.
    var cell = Deferred[Int]()
    var left = IO[Int, Int].never().start().flat_map(One(cell.copy()))
    var driver = Driver(left^.both(IO[Int, Int].pure(2)).map(Sum()), CancellationToken(), Clock(), IORuntimeConfig())
    settle(driver)
    var listed = driver.fibers()
    var owned_by_side = False
    for index in range(len(listed)):
        if listed[index].owner != 0:
            owned_by_side = True
    check(owned_by_side, "a fiber started by a side of both is the root's, owned by that side")
    fire(cell)
    while not driver.poll().completed:
        pass
    var outcome = driver^.finish()
    check(Bool(outcome) and outcome.value().is_ok() and outcome.take()._take_ok() == 3, "the pair completes")

    # An IO lifted into a leaf hosts its own fibers, which the driver does not list.
    var inner_cell = Deferred[Int]()
    var inner = IO[Int, Int].never().start().flat_map(One(inner_cell.copy()))
    var lifted = Driver(IO[Int, Int].lift(inner^), CancellationToken(), Clock(), IORuntimeConfig())
    settle(lifted)
    check(len(lifted.fibers()) == 0, "a fiber hosted by an IO inside a leaf is not the root's")
    fire(inner_cell)
    while not lifted.poll().completed:
        pass
    _ = lifted^.finish()


def main() raises:
    owners_and_status()
    runnable_before_first_poll()
    nested_hosts_not_listed()
    print("fiber snapshot: owners, runnable, suspended and draining fibers, nested hosts excluded")
