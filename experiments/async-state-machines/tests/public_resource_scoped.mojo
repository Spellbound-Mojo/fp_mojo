"""Resource.use_scoped lends a move-only resource on every poll; make_case releases with the exact exit."""
from std.os import abort
from std.memory import ArcPointer
from fp.data import Result, Ok, Err, NonEmptyList
from fp.effects import EffectFailure, ExitCase, IOContext, CancellationToken, Outcome
from fp.effects.async_runtime import IO, Resource, Driver, run
from fp.effects.async_runtime.protocols import ScopedMachine, CleanupMachine, Step, Wait


@fieldwise_init
struct Connection(Movable):
    """A move-only resource; bodies borrow it and never copy it."""
    var id: Int
    var log: ArcPointer[List[Int]]


@fieldwise_init
struct ReadTwice(ScopedMachine):
    """Read the borrowed connection, suspend, then read it again."""
    var reads: Int
    comptime Input = Connection
    comptime Value = Int
    comptime Error = Int

    def poll[p: ImmOrigin](mut self, ref[p] connection: Connection, context: IOContext[Int]) -> Step[Int, Int]:
        connection.log[].append(connection.id)
        self.reads += 1
        if self.reads < 2:
            return .pending(Wait())
        return .ready(Optional(Result[Int, EffectFailure[Int]](Ok(connection.id * 10))))


@fieldwise_init
struct Fail(ScopedMachine):
    comptime Input = Connection
    comptime Value = Int
    comptime Error = Int

    def poll[p: ImmOrigin](mut self, ref[p] connection: Connection, context: IOContext[Int]) -> Step[Int, Int]:
        return .ready(Optional(Result[Int, EffectFailure[Int]](Err(EffectFailure[Int](NonEmptyList(connection.id), False)))))


@fieldwise_init
struct Forever(ScopedMachine):
    comptime Input = Connection
    comptime Value = Int
    comptime Error = Int

    def poll[p: ImmOrigin](mut self, ref[p] connection: Connection, context: IOContext[Int]) -> Step[Int, Int]:
        if context.canceled():
            return .ready(None)
        return .pending(Wait.never())


@fieldwise_init
struct Close(CleanupMachine):
    """Log the exact exit: 100 success, 200 failure, 300 cancellation."""
    comptime Input = Connection
    comptime Error = Int

    def poll[p: ImmOrigin](mut self, ref[p] connection: Connection, exit: ExitCase[Int], context: IOContext[Int]) -> Step[NoneType, Int]:
        connection.log[].append(100 if exit.is_success() else 200 if exit.is_error() else 300)
        return .ready(Optional(Result[NoneType, EffectFailure[Int]](Ok(NoneType()))))


def connection(id: Int, log: ArcPointer[List[Int]]) -> Resource[Connection, Int]:
    return Resource[Connection, Int].make_case(IO[Connection, Int].pure(Connection(id, log.copy())), Close())


def main():
    var log = ArcPointer(List[Int]())
    var read = run(connection(7, log).use_scoped(ReadTwice(0)))
    check(read.take()._take_ok() == 70, "the scoped body completes after suspending")
    check(log[] == List[Int]([7, 7, 100]), "each poll borrows the connection; release sees success")
    log[].clear()
    var failed = run(connection(8, log).use_scoped(Fail()))
    check(failed.take()._take_err().errors.first() == 8 and log[] == List[Int]([200]), "release sees the failure")
    log[].clear()
    var driver = Driver(connection(9, log).use_scoped(Forever()))
    _ = driver.poll()
    driver.request_cancel()
    while not driver.poll().completed:
        pass
    check(not driver^.finish() and log[] == List[Int]([300]), "release sees cancellation")
    print("resource scoped: per-poll loans of a move-only resource, release with the exact exit")


def check(condition: Bool, message: String):
    if not condition:
        abort(message)
