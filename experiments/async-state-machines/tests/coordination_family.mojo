"""Coordination result aliases retain the selected async family through Pipeline."""
from fp.effects._async.coordination import Deferred, Queue, Semaphore
from fp.effects._async.application import pure, Pure
from fp.effects._async.kernel import run
from fp.functions import pipeline
from foundation import check


def get(value: Deferred[Int]) -> Deferred[Int].Get[Int]:
    return value.get[Int]()


def take(queue: Queue[Int]) -> Queue[Int].Take[Int]:
    return queue.take[Int]()


def limited(gate: Semaphore) -> Semaphore.WithPermit[Pure[Int, Int]]:
    return gate.with_permit(pure[Int](41))


def add(var value: Int) -> Int:
    return value + 1


def main() raises:
    var value = Deferred[Int]()
    var complete: Deferred[Int].Complete[Int] = value.complete[Int](41)
    var completed = run(complete^)
    check(completed.take()._take_ok(), "deferred completion alias")
    var read = run(pipeline(get(value)).map(add).get())
    check(read.take()._take_ok() == 42, "waiting reader selects Async family")
    var queue = Queue[Int](1)
    var offer: Queue[Int].Offer[Int] = queue.offer[Int](41)
    _ = run(offer^)
    var item = run(pipeline(take(queue)).map(add).get())
    check(item.take()._take_ok() == 42, "queue take selects Async family")
    var gate = Semaphore(1)
    var result = run(pipeline(limited(gate)).map(add).get())
    check(result.take()._take_ok() == 42, "scoped permit selects Async family")
    var available: Semaphore.Available[Int] = gate.available[Int]()
    var after = run(available^)
    check(after.take()._take_ok() == 1, "permit released before the continuation")
    print("coordination family: logical result aliases, selected Pipeline, scoped permit release")
