"""Shared cells, owned permits, and queues use the same deferred IO family."""
from fp.effects import IOContract, ReaderAction, run_io, delay
from fp.effects import Ref, Deferred, Semaphore, Queue


def value[P: ReaderAction](var program: P) raises -> P.Value where IOContract[P].Compatible:
    var outcome = run_io(program^)
    if not outcome:
        raise Error("operation canceled")
    var result = outcome.take()
    if result.is_err():
        raise Error("operation failed")
    return result^._take_ok()


def increment(var current: Int) -> Int:
    return current + 1


def answer() -> Int:
    return 42


def main() raises:
    var counter = Ref(0)
    _ = value(counter.update[Error](increment))
    print("counter:", value(counter.get[Error]()))
    var deferred = Deferred[String]()
    _ = value(deferred.complete[Error](String("ready")))
    print("deferred:", value(deferred.get[Error]()))
    var semaphore = Semaphore(1)
    print("protected:", value(semaphore.with_permit(delay[Error](answer))))
    var queue = Queue[String](2)
    _ = value(queue.offer[Error](String("first")))
    _ = value(queue.offer[Error](String("second")))
    print("queue:", value(queue.take[Error]()), value(queue.take[Error]()))
