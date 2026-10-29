"""Async coordination preserves external payload and error origins."""
from state_machine import Deferred, Queue, Semaphore, Driver, run
from foundation import Borrowed, check
from async_coordination import value


def exercise[o: ImmOrigin](ref[o] owner: List[Int]) raises:
    comptime View = Span[Int, o]
    var deferred = Deferred[View]()
    var reader = Driver(deferred.get[View]())
    check(not reader.poll(10).runnable, "borrowed reader parks")
    check(value(deferred.complete[View](Span(owner))), "external view completes shared value")
    check(reader.poll(10).completed, "borrowed reader wakes")
    var completed = reader^.finish()
    var view = completed.take()._take_ok()
    _ = deferred^
    check(view[1] == 17, "result survives coordination owner with original origin")
    var queue = Queue[View](1)
    _ = value(queue.offer[View](Span(owner)))
    var removed = value(queue.take[View]())
    _ = queue^
    check(removed[0] == 13, "queue transfer preserves external origin")
    var semaphore = Semaphore(1)
    var success = run(semaphore.with_permit(Borrowed(Pointer(to=owner), 0, False)))
    check(success.take()._take_ok()[1] == 17, "permit scope preserves borrowed value")
    var failure = run(semaphore.with_permit(Borrowed(Pointer(to=owner), 0, True)))
    var error = failure.take()._take_err()
    check(error.errors.first()[0] == 13, "permit scope preserves exact borrowed error")
    check(value(semaphore.available[View]()) == 1, "permit restored after success and failure")


def main() raises:
    var owner = List[Int]([13, 17])
    exercise(owner)
    print("coordination origins: deferred, queue, permit values and errors")
