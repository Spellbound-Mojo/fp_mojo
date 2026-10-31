"""Driver's host notifier: called for wakes delivered between polls, never during one or after finish."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import Thunk, OnceUnary
from fp.effects import CancellationToken
from fp.effects.async_runtime import IO, Deferred, Driver, Clock, IORuntimeConfig, run


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


@fieldwise_init
struct Count(Thunk):
    """A host notifier that counts its calls."""
    var calls: ArcPointer[Int]
    comptime Out = NoneType

    def call(self) -> NoneType:
        self.calls[] += 1
        return None


@fieldwise_init
struct Second(OnceUnary):
    var cell: Deferred[Int]
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var first: Int) -> IO[Int, Int]:
        return self.cell.get[Int]().map(Add(first))


@fieldwise_init
struct Add(OnceUnary):
    var base: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return self.base + value


def idle(mut driver: Driver[IO[Int, Int]]):
    while True:
        var progress = driver.poll()
        check(not progress.completed, "the program waits")
        if not progress.runnable:
            return


def main():
    var calls = ArcPointer(0)
    var first = Deferred[Int]()
    var second = Deferred[Int]()
    var program = first.get[Int]().flat_map(Second(second.copy()))
    var driver = Driver(program^, CancellationToken(), Clock(), IORuntimeConfig(), Count(calls.copy()))
    check(calls[] == 0, "constructing the driver does not notify")
    idle(driver)
    check(calls[] == 0, "work found during polls does not notify")
    # An external event between polls makes the root runnable: one call.
    _ = run(first.complete[Int](2))
    check(calls[] == 1, "an external wake notifies the host once")
    _ = run(first.complete[Int](9))
    check(calls[] == 1, "a duplicate event does not wake again")
    idle(driver)
    check(calls[] == 1, "the woken poll does not notify")
    _ = run(second.complete[Int](3))
    check(calls[] == 2, "a second external wake notifies again")
    while not driver.poll().completed:
        pass
    var outcome = driver^.finish()
    check(Bool(outcome) and outcome.take()._take_ok() == 5, "the program completes")
    check(calls[] == 2, "finishing does not notify")
    print("host notifier: external wakes only, once per idle period, none during polls or after finish")
