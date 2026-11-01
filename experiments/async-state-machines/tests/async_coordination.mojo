"""Async coordination parks on state changes and shares canonical transitions."""
from std.memory import ArcPointer
from fp.effects import CancellationToken, Outcome
from fp.effects.coordination import _try_lock
from fp.callables import OnceUnary
from fp.effects._async.engine import IO, Fiber
from state_machine import Deferred, Queue, Semaphore, Driver, Machine, Completion, Signal, callback, pure, run
from foundation import check
from callbacks import Register, Withdraw


def value[P: Machine](var program: P) -> P.Value:
    var outcome = run(program^)
    check(Bool(outcome) and outcome.value().is_ok(), "expected successful coordination")
    return outcome.take()._take_ok()


@fieldwise_init
struct StartReaders(OnceUnary):
    """Start readers as fibers, keeping their handles, then join them all."""
    var deferred: Deferred[Int]
    var left: Int
    var handles: List[Fiber[Int, Int]]
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[List[Int], Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[List[Int], Int]:
        self.handles.append(fiber^)
        if self.left == 0:
            return IO[List[Int], Int].pure(List[Int]()).flat_map(JoinAll(self.handles^))
        return self.deferred.get[Int]().start().flat_map(StartReaders(self.deferred.copy(), self.left - 1, self.handles^))


@fieldwise_init
struct JoinAll(OnceUnary):
    var handles: List[Fiber[Int, Int]]
    comptime Arg = List[Int]
    comptime Out = IO[List[Int], Int]

    def call_once(deinit self, var results: List[Int]) -> IO[List[Int], Int]:
        if not len(self.handles):
            return IO[List[Int], Int].pure(results^)
        var fiber = self.handles.pop(0)
        return fiber^.join().flat_map(Collect(results^, self.handles^))


@fieldwise_init
struct Collect(OnceUnary):
    var results: List[Int]
    var handles: List[Fiber[Int, Int]]
    comptime Arg = Outcome[Int, Int]
    comptime Out = IO[List[Int], Int]

    def call_once(deinit self, var outcome: Outcome[Int, Int]) -> IO[List[Int], Int]:
        check(Bool(outcome) and outcome.value().is_ok(), "each reader succeeds")
        self.results.append(outcome.take()._take_ok())
        return IO[List[Int], Int].pure(self.results^).flat_map(JoinAll(self.handles^))


def deferred_readers():
    var deferred = Deferred[Int]()
    var program = deferred.get[Int]().start().flat_map(StartReaders(deferred.copy(), 15, List[Fiber[Int, Int]]()))
    var readers = Driver(program^)
    check(not readers.poll(100).runnable, "all deferred readers park")
    check(readers.poll(100).polls == 0, "no polling before completion")
    var canceled = Driver(deferred.get[Int]())
    _ = canceled.poll(10)
    canceled.cancel()
    check(canceled.poll(10).completed, "canceled operation drained")
    check(not canceled^.finish(), "waiting reader cancels independently")
    check(value(deferred.complete[Int](42)), "first completion wins")
    check(not value(deferred.complete[Int](99)), "duplicate completion rejected")
    check(readers.poll(100).completed, "completion wakes all readers")
    var outcome = readers^.finish()
    var results = outcome.take()._take_ok()
    check(len(results) == 16, "all reader results retained")
    for result in results:
        check(result == 42, "each reader receives the same value")
    check(value(deferred.get[Int]()) == 42, "late reader completes immediately")
    var guarded = _try_lock(deferred._source._state._cell)
    check(Bool(guarded), "take guard for deterministic contention")
    var busy = Driver(deferred.get[Int]())
    var limited = busy.poll(3)
    check(limited.polls == 3 and limited.runnable and not limited.completed, "contention respects nonblocking budget")
    _ = guarded^
    check(busy.poll(1).completed, "retry succeeds after guard release")
    _ = busy^.finish()


def queue_waiters() raises:
    var queue = Queue[Int](1)
    _ = value(queue.offer[Int](10))
    var first = Driver(queue.offer[Int](20))
    var second = Driver(queue.offer[Int](30))
    check(not first.poll(10).runnable and not second.poll(10).runnable, "full queue parks both offerers")
    for _ in range(10):
        check(first.poll(10).polls == 0 and second.poll(10).polls == 0, "failed offers do not wake one another")
    second.cancel()
    check(second.poll(10).completed, "canceled operation drained")
    check(not second^.finish(), "full-queue offer cancels")
    check(value(queue.take[Int]()) == 10, "FIFO initial value")
    check(first.poll(10).completed, "space wakes pending offer")
    _ = first^.finish()
    check(value(queue.take[Int]()) == 20, "accepted pending value retained")
    var a = Driver(queue.take[Int]())
    var b = Driver(queue.take[Int]())
    _ = a.poll(10)
    _ = b.poll(10)
    check(a.poll(10).polls == 0 and b.poll(10).polls == 0, "empty takers do not notify one another")
    _ = value(queue.offer[Int](40))
    a.cancel()
    check(a.poll(10).completed, "canceled operation drained")
    check(not a^.finish(), "cancel before dequeue leaves buffered owner")
    check(b.poll(10).completed, "remaining taker receives value")
    var taken = b^.finish()
    check(taken.take()._take_ok() == 40 and value(queue.size[Int]()) == 0, "one dequeue only")
    var absent = value(queue.try_take[Int]())
    check(not absent, "try_take returns absence")
    var offered = value(queue.try_offer[Int](50))
    check(not offered, "try_offer accepts into space")
    var rejected = value(queue.try_offer[Int](60))
    check(rejected.take() == 60 and value(queue.take[Int]()) == 50, "try_offer returns rejected input")


def semaphore_lifecycle() raises:
    var semaphore = Semaphore(1)
    var held = value(semaphore.acquire[Int]())
    var waiting = Driver(semaphore.acquire[Int]())
    check(not waiting.poll(10).runnable and value(semaphore.available[Int]()) == 0, "permit waiter parks")
    var canceled_use = Driver(semaphore.with_permit(pure[Int](7)))
    _ = canceled_use.poll(100)
    canceled_use.cancel()
    check(canceled_use.poll(100).completed, "canceled operation drained")
    check(not canceled_use^.finish(), "with_permit acquisition remains cancelable")
    _ = held^
    check(waiting.poll(10).completed, "canonical Permit destruction wakes acquisition")
    var next = waiting^.finish()
    check(value(semaphore.available[Int]()) == 0, "exactly one permit reserved")
    _ = next^
    check(value(semaphore.available[Int]()) == 1, "permit restored once")
    var saved = ArcPointer(Optional[Completion[Int, Int]]())
    var counts = ArcPointer(List[Int]([0, 0]))
    var gate = Signal()
    var protected = Driver(semaphore.with_permit(callback(Register(saved.copy(), counts.copy(), 0, False), Withdraw(counts.copy(), gate.copy(), False))))
    check(not protected.poll(100).runnable and counts[][0] == 1, "protected callback enters while holding permit")
    var neighbor = Driver(semaphore.acquire[Int]())
    check(not neighbor.poll(10).runnable, "neighbor waits for protected work")
    protected.cancel()
    check(not protected.poll(100).runnable and counts[][1] == 1, "protected withdrawal suspends")
    check(neighbor.poll(10).polls == 0 and value(semaphore.available[Int]()) == 0, "permit lives through suspended cleanup")
    gate.notify()
    check(protected.poll(100).completed, "canceled operation drained")
    check(not protected^.finish(), "cleanup drains before protected cancellation returns")
    check(neighbor.poll(10).completed, "permit released after cleanup")
    var permit = neighbor^.finish()
    _ = permit^
    check(value(semaphore.available[Int]()) == 1, "all permits restored")


def main() raises:
    deferred_readers()
    queue_waiters()
    semaphore_lifecycle()
    print("async coordination: deferred readers, bounded queues, contention budgets, cancelable permits, suspended cleanup")
