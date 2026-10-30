"""Coordination operations return IO, which selects the Async family through Pipeline."""
from fp.effects._async.coordination import Deferred, Queue, Semaphore
from fp.effects._async.kernel import run
from fp.effects._async.engine import IO
from fp.functions import pipeline
from foundation import check


def add(var value: Int) -> Int:
    return value + 1


def main() raises:
    var value = Deferred[Int]()
    var complete: IO[Bool, Int] = value.complete[Int](41)
    var completed = run(complete^)
    check(completed.take()._take_ok(), "deferred completion returns IO")
    var read = run(pipeline(value.get[Int]()).map(add).get())
    check(read.take()._take_ok() == 42, "waiting reader selects Async family")
    var queue = Queue[Int](1)
    var offer: IO[NoneType, Int] = queue.offer[Int](41)
    _ = run(offer^)
    var item = run(pipeline(queue.take[Int]()).map(add).get())
    check(item.take()._take_ok() == 42, "queue take selects Async family")
    var gate = Semaphore(1)
    var result = run(pipeline(gate.with_permit(IO[Int, Int].pure(41))).map(add).get())
    check(result.take()._take_ok() == 42, "scoped permit selects Async family")
    var available: IO[Int, Int] = gate.available[Int]()
    var after = run(available^)
    check(after.take()._take_ok() == 1, "permit released before the continuation")
    print("coordination family: IO results, selected Pipeline, scoped permit release")
