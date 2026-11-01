"""Cancellation preserves committed transitions and destroys every owner once."""
from std.memory import ArcPointer
from fp.callables import OnceUnary, BorrowCallable
from fp.callables._receiver import _unary_once_as
from fp.effects import CancellationToken, Permit, Ref
from fp.effects.coordination import _TryOffer, _TryTake, _Reserve
from state_machine import Deferred, Queue, Semaphore, Driver, run
from state_machine.coordination import _Once
from async_coordination import value
from foundation import check


@fieldwise_init
struct Owner(Movable):
    var id: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


struct CopyOwner(Copyable):
    var counts: ArcPointer[List[Int]]
    def __init__(out self, counts: ArcPointer[List[Int]]):
        self.counts = counts.copy()
        self.counts[][0] += 1
    def __init__(out self, *, copy: Self):
        self.counts = copy.counts.copy()
        self.counts[][0] += 1
    def __deinit__(deinit self):
        self.counts[][1] += 1


@fieldwise_init
struct CancelAfter[F: OnceUnary](OnceUnary):
    var function: Self.F
    var token: CancellationToken
    comptime Arg = Self.F.Arg
    comptime Out = Self.F.Out
    def call_once(deinit self, var input: Self.Arg) -> Self.Out:
        comptime assert Self.F.Error == Never
        var output = _unary_once_as[Never](self.function^, input^)
        self.token.cancel()
        return output^


def queue_owners() raises:
    var queue = Queue[Owner](1)
    var drops = ArcPointer(0)
    var unopened = queue.offer[Int](Owner(1, drops.copy()))
    _ = unopened^
    var before = CancellationToken()
    before.cancel()
    check(not run(queue.offer[Int](Owner(2, drops.copy())), before), "unopened cancellation")
    check(drops[] == 2, "unopened inputs destroyed once")
    _ = value(queue.offer[Int](Owner(3, drops.copy())))
    var blocked = Driver(queue.offer[Int](Owner(4, drops.copy())))
    check(not blocked.poll(10).runnable and drops[] == 2, "pending offer retains move-only input")
    var moved = blocked^
    moved.cancel()
    check(moved.poll(10).completed, "moved pending offer drains")
    check(not moved^.finish() and drops[] == 3, "canceled pending input destroyed once")
    var rejected = value(queue.try_offer[Int](Owner(5, drops.copy())))
    check(rejected.value().id == 5 and drops[] == 3, "rejected owner returned intact")
    _ = rejected^
    var taken = value(queue.take[Int]())
    check(taken.id == 3 and drops[] == 4, "buffered owner transferred once")
    _ = taken^
    check(drops[] == 5, "returned owner destroyed once")

    var enqueue_token = CancellationToken()
    var enqueue = queue._source._state.modify[Int, Optional[Owner]](CancelAfter(_TryOffer(Owner(6, drops.copy()), 1), enqueue_token.copy()))
    check(not run(_Once(enqueue^), enqueue_token), "late enqueue cancellation suppresses result")
    check(value(queue.size[Int]()) == 1 and drops[] == 5, "committed enqueue survives cancellation")
    var retained = value(queue.take[Int]())
    check(retained.id == 6, "committed input remains available")
    _ = retained^
    _ = value(queue.offer[Int](Owner(7, drops.copy())))
    var dequeue_token = CancellationToken()
    var dequeue = queue._source._state.modify[Int, Optional[Owner]](CancelAfter(_TryTake[Owner](), dequeue_token.copy()))
    check(not run(_Once(dequeue^), dequeue_token), "late dequeue cancellation suppresses result")
    check(value(queue.size[Int]()) == 0 and drops[] == 7, "committed dequeue destroys unobserved owner without rollback")
    _ = value(queue.offer[Int](Owner(8, drops.copy())))
    _ = queue^
    check(drops[] == 8, "final queue destruction drops remaining buffer")


def deferred_owners():
    var counts = ArcPointer(List[Int]([0, 0]))
    var deferred = Deferred[CopyOwner]()
    var unopened = deferred.complete[Int](CopyOwner(counts))
    _ = unopened^
    check(counts[][1] == 1, "unused completion owns its input")
    check(value(deferred.complete[Int](CopyOwner(counts))), "winner retained")
    check(not value(deferred.complete[Int](CopyOwner(counts))), "duplicate rejected")
    check(counts[][0] == 3 and counts[][1] == 2, "no completion payload copies")
    var first = value(deferred.get[Int]())
    var second = value(deferred.get[Int]())
    check(counts[][0] == 5 and counts[][1] == 2, "one owned copy per reader")
    _ = first^
    _ = second^
    _ = deferred^
    check(counts[][0] == counts[][1], "all shared and returned owners destroyed once")


def late_reservation() raises:
    var semaphore = Semaphore(1)
    var token = CancellationToken()
    var reserve = _Reserve(semaphore._source._state.copy(), semaphore._source._token.copy())
    var attempt = semaphore._source._state.modify[Int, Optional[Permit]](CancelAfter(reserve^, token.copy()))
    check(not run(_Once(attempt^), token), "late canceled reservation suppresses permit")
    # Destruction reenters this same Ref: settling under the guard deadlocks.
    check(value(semaphore.available[Int]()) == 1, "canceled reserved permit restored once after unlock")


@fieldwise_init
struct FailRead(BorrowCallable):
    var drops: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = Int
    comptime Failure = Owner
    def invoke(self, ref value: Int) raises Owner -> Int:
        raise Owner(value, self.drops.copy())


def exact_error():
    var drops = ArcPointer(0)
    var state = Ref(19)
    var outcome = run(_Once(state.inspect[Owner](FailRead(drops.copy()))))
    var error = outcome.take()._take_err()
    check(error.errors.first().id == 19 and drops[] == 0, "exact move-only observation error retained")
    _ = error^
    check(drops[] == 1, "observation error destroyed once")


def main() raises:
    queue_owners()
    deferred_owners()
    late_reservation()
    exact_error()
    print("coordination ownership: queued values, reader copies, late cancellation, permit restoration, exact errors")
