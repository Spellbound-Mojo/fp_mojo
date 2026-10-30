"""Coordination and Resource on IO: shared waits, permits, ordered releases and exact errors."""
from std.memory import ArcPointer
from fp.callables import BorrowOnceCallable
from fp.effects._async.coordination import Deferred, Queue, Semaphore
from fp.effects._async.io_resource import Resource
from state_machine import IO, run
from foundation import check


@fieldwise_init
struct Handle(Movable):
    var id: Int
    var log: ArcPointer[List[Int]]


@fieldwise_init
struct Release(BorrowOnceCallable):
    """Log the released handle's id."""
    comptime Payload = Handle
    comptime Result = IO[NoneType, Int]

    def invoke_once(deinit self, ref handle: Handle) -> IO[NoneType, Int]:
        handle.log[].append(-handle.id)
        var unit: NoneType = None
        return IO[NoneType, Int].pure(unit)


@fieldwise_init
struct FailRelease(BorrowOnceCallable):
    comptime Payload = Handle
    comptime Result = IO[NoneType, Int]

    def invoke_once(deinit self, ref handle: Handle) -> IO[NoneType, Int]:
        return IO[NoneType, Int].raise_error(handle.id * 10)


@fieldwise_init
struct Child(BorrowOnceCallable):
    """Acquire a dependent handle from the borrowed parent."""
    comptime Payload = Handle
    comptime Result = Resource[Handle, Int]

    def invoke_once(deinit self, ref parent: Handle) -> Resource[Handle, Int]:
        parent.log[].append(parent.id + 1)
        return Resource[Handle, Int].make(IO[Handle, Int].pure(Handle(parent.id + 1, parent.log.copy())), Release())


@fieldwise_init
struct Id(BorrowOnceCallable):
    comptime Payload = Handle
    comptime Result = Int

    def invoke_once(deinit self, ref handle: Handle) -> Int:
        return handle.id


def handle(id: Int, log: ArcPointer[List[Int]]) -> Resource[Handle, Int]:
    log[].append(id)
    return Resource[Handle, Int].make(IO[Handle, Int].pure(Handle(id, log.copy())), Release())


def read(handle: Handle) -> IO[Int, Int]:
    handle.log[].append(100)
    return IO[Int, Int].pure(handle.id)


def fail(handle: Handle) -> IO[Int, Int]:
    return IO[Int, Int].raise_error(7)


def read_int(value: Int) -> IO[Int, Int]:
    return IO[Int, Int].pure(value)


def value(var io: IO[Int, Int]) -> Int:
    var outcome = run(io^)
    return outcome.take()._take_ok()


def errors(var io: IO[Int, Int]) -> List[Int]:
    var outcome = run(io^)
    return outcome.take()._take_err().into_errors().into_list()


def coordination() raises:
    var cell = Deferred[Int]()
    var pair = run(cell.get[Int]().both(cell.complete[Int](5)))
    var got = pair.take()._take_ok()
    check(got[0] == 5 and got[1], "a waiting get receives the completed value")
    var queue = Queue[Int](1)
    var moved = run(queue.take[Int]().both(queue.offer[Int](7)))
    check(moved.take()._take_ok()[0] == 7, "take waits for an offer")
    var gate = Semaphore(1)
    var limited = run(gate.with_permit(IO[Int, Int].pure(3)))
    check(limited.take()._take_ok() == 3, "with_permit runs the body")
    var available = run(gate.available[Int]())
    check(available.take()._take_ok() == 1, "with_permit releases its permit")


def resources():
    var log = ArcPointer(List[Int]())
    check(value(handle(1, log).use(read)) == 1, "use lends the acquired handle")
    check(log[] == List[Int]([1, 100, -1]), "acquire, use, then release")
    log[].clear()
    var nested = handle(1, log).flat_map(Child()).use(read)
    check(value(nested^) == 2, "flat_map exposes the dependent handle")
    check(log[] == List[Int]([1, 2, 100, -2, -1]), "dependent release precedes its parent")
    log[].clear()
    check(errors(handle(3, log).use(fail)) == List[Int]([7]) and log[] == List[Int]([3, -3]), "release runs after a failed body")
    var failing = Resource[Handle, Int].make(IO[Handle, Int].pure(Handle(4, log.copy())), FailRelease())
    check(errors(failing^.use(fail)) == List[Int]([7, 40]), "release errors follow body errors")
    log[].clear()
    var mapped = handle(5, log).map(Id()).use(read_int)
    check(value(mapped^) == 5 and log[] == List[Int]([5, -5]), "map keeps the release owner")
    check(value(Resource[Int, Int].pure(9).use(read_int)) == 9, "a pure resource")


def main() raises:
    coordination()
    resources()
    print("io resources: Deferred, Queue and Semaphore as IO; Resource use, dependent release order, failures and projections")
