"""Runtime admission, owned draining, producer progress and retained handles."""
from std.memory import ArcPointer
from fp.effects import CancellationToken, IOContext
from state_machine import Nursery, Spawner, Machine, Step, Wait, Signal, Task, Pure, pure, run, both, Scope, Completion, Callback, callback
from foundation import check, success, Resource, Failure, Yielding
from children import Controlled, ScopedPipeline, Acquire, Release, Terminal
from callbacks import Register, Withdraw


@fieldwise_init
struct Feed(Machine):
    var spawn: Spawner[Yielding]
    var trace: ArcPointer[List[Int]]
    var next: Int
    var limit: Int
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if self.next == self.limit:
            self.spawn.close()
            return success[Int, Int](self.next)
        check(not self.spawn.try_spawn(Yielding(self.trace.copy(), self.next, 3)), "producer admission")
        if self.next > 8:
            check(len(self.trace[]) > 0, "children progress while producer admits")
        self.next += 1
        return .pending(Wait())


def dynamic_success():
    var nursery = Nursery[Yielding](100)
    var spawn = nursery.spawner()
    var trace = ArcPointer(List[Int]())
    var result = run(both(nursery^, Feed(spawn.copy(), trace.copy(), 0, 100)))
    var values = result.take()._take_ok()
    check(len(values[0]) == 100 and values[1] == 100, "runtime child count")
    for i in range(100):
        check(values[0][i] == i, "successes in admission order")
    check(len(trace[]) == 400, "each child polled exactly four times")
    check(Bool(spawn.try_spawn(Yielding(trace.copy(), 100, 0))), "late handle rejects after completion")


def parked_admission():
    var nursery = Nursery[Pure[Int, Int]](2)
    var spawn = nursery.spawner()
    var task = Task(nursery^, CancellationToken())
    check(task.tick() and not task.tick(), "empty open nursery parks")
    check(not spawn.try_spawn(pure[Int](13)), "admit after park")
    check(task.tick() and not task.tick(), "submission wakes owner then waits for close")
    check(not spawn.try_spawn(pure[Int](17)), "second admission")
    var rejected = spawn.try_spawn(pure[Int](19))
    check(Bool(rejected), "total admission limit includes completed children")
    var returned = run(rejected.take())
    check(returned.take()._take_ok() == 19, "rejected recipe remains usable")
    spawn.close()
    var moved = task^
    while not moved.done():
        check(moved.tick(), "closed nursery drains and collects")
    var result = moved^.finish()
    var values = result.take()._take_ok()
    check(len(values) == 2 and values[0] == 13 and values[1] == 17, "ordered admission after parked owner")


def canceled_scope():
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var body = Signal()
    var a = Signal()
    var b = Signal()
    var c = Signal()
    var nursery = Nursery[Controlled](4)
    var spawn = nursery.spawner()
    check(not spawn.try_spawn(Controlled(body.copy(), a.copy(), stats.copy(), 0, True, 0)), "first child admitted")
    var task = Task(Scope(Acquire(stats.copy()), ScopedPipeline(nursery^), Release(stats.copy(), 0)), CancellationToken())
    while stats[][0] == 0:
        check(task.tick(), "first entered child")
    check(not spawn.try_spawn(Controlled(body.copy(), b.copy(), stats.copy(), 1, False, 0)), "spawn during active scope")
    check(not spawn.try_spawn(Controlled(body.copy(), c.copy(), stats.copy(), 2, True, 0)), "third child admitted")
    while stats[][0] + stats[][1] + stats[][2] < 3:
        check(task.tick(), "new children enter")
    check(not task.tick(), "all children parked")
    task.cancel()
    while stats[][0] + stats[][1] + stats[][2] < 6:
        check(task.tick(), "parent cancellation propagates")
    check(Bool(spawn.try_spawn(Controlled(body.copy(), c.copy(), stats.copy(), 2, True, 0))), "cancellation closes admission")
    # A rejected submission may notify the admission signal once.
    _ = task.tick()
    check(not task.tick() and stats[][3] == 0, "outer resource stays alive while cleanup parks")
    task.cancel()
    check(not task.tick(), "repeated cancellation does not spin masked cleanup")
    var moved = task^
    c.notify()
    check(moved.tick() and not moved.done(), "last child's cleanup completes first")
    check(not moved.tick(), "other cleanup stays parked")
    a.notify()
    b.notify()
    while not moved.done():
        check(moved.tick(), "drain children before outer release")
    var outcome = moved^.finish()
    var failure = outcome.take()._take_err()
    check(failure.canceled, "cancellation retained with failure")
    var errors = failure^.into_errors().into_list()
    check(len(errors) == 2 and errors[0].code == 40 and errors[1].code == 42, "errors in admission order")
    check(stats[][3] == 1 and stats[][5] == 2, "outer cleanup completes after dynamic descendants")


def unopened_and_rejected():
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var nursery = Nursery[Pure[Resource, Failure]](1)
    var spawn = nursery.spawner()
    check(not spawn.try_spawn(pure[Failure](Resource(String("queued"), stats.copy()))), "unopened owner accepts recipe")
    var returned = spawn.try_spawn(pure[Failure](Resource(String("returned"), stats.copy())))
    check(Bool(returned) and stats[][3] == 0, "rejection preserves move-only payload")
    _ = nursery^
    check(stats[][3] == 1, "unopened owner drops queued payload once")
    _ = returned^
    check(stats[][3] == 2, "caller owns rejected payload")
    var late = spawn.try_spawn(pure[Failure](Resource(String("late"), stats.copy())))
    check(Bool(late) and stats[][3] == 2, "retained handle is closed without destroying rejection")
    _ = late^
    check(stats[][3] == 3, "late rejected payload dropped once")
    var empty = Nursery[Pure[Int, Int]](0)
    empty.spawner().close()
    var result = run(empty^)
    check(len(result.take()._take_ok()) == 0, "closed empty nursery succeeds")


def masking_and_unopened_cancel():
    var trace = ArcPointer(List[Int]())
    var nursery = Nursery[Yielding](1)
    var spawn = nursery.spawner()
    _ = spawn.try_spawn(Yielding(trace.copy(), 1, 1))
    spawn.close()
    var task = Task(nursery^, CancellationToken())
    task.context._masked = True
    task.cancel()
    while not task.done():
        check(task.tick(), "masked parent keeps independent child running")
    var result = task^.finish()
    check(result.take()._take_ok()[0] == 1 and len(trace[]) == 2, "parent mask does not pre-cancel child")
    var unopened = Nursery[Yielding](1)
    var handle = unopened.spawner()
    _ = handle.try_spawn(Yielding(trace.copy(), 2, 0))
    var token = CancellationToken()
    token.cancel()
    var skipped = run(unopened^, token)
    check(not skipped and len(trace[]) == 2, "pre-canceled root never enters queued child")
    check(Bool(handle.try_spawn(Yielding(trace.copy(), 3, 0))), "pre-canceled root closes retained handle")


def failure_closes_admission():
    for queued in range(2):
        var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
        var signal = Signal()
        var nursery = Nursery[Terminal](3)
        var spawn = nursery.spawner()
        _ = spawn.try_spawn(Terminal(signal.copy(), stats.copy(), 0, 1, True))
        if queued:
            _ = spawn.try_spawn(Terminal(signal.copy(), stats.copy(), 1, 0, False))
        var task = Task(nursery^, CancellationToken())
        check(task.tick() and stats[][0] == 1, "first admitted child fails")
        check(Bool(spawn.try_spawn(Terminal(signal.copy(), stats.copy(), 2, 0, False))), "failure closes admission immediately")
        while not task.done():
            check(task.tick(), "failed nursery drains queued cancellation")
        var outcome = task^.finish()
        var error = outcome.take()._take_err()
        check(error.errors.first().code == 11 and error.canceled == Bool(queued), "only actual canceled child adds cancellation flag")
        check(stats[][0] == 1 and stats[][1] == 0 and stats[][2] == 0, "failed child frozen and queued children unopened")


def failure_drains_entered_callback():
    var left = ArcPointer(Optional[Completion[Int, Int]]())
    var right = ArcPointer(Optional[Completion[Int, Int]]())
    var a = ArcPointer(List[Int]([0, 0]))
    var b = ArcPointer(List[Int]([0, 0]))
    var release_a = Signal()
    var release_b = Signal()
    var nursery = Nursery[Callback[Register, Withdraw]](3)
    var spawn = nursery.spawner()
    _ = spawn.try_spawn(callback(Register(left.copy(), a.copy(), 2, False), Withdraw(a.copy(), release_a.copy(), False)))
    _ = spawn.try_spawn(callback(Register(right.copy(), b.copy(), 0, False), Withdraw(b.copy(), release_b.copy(), True)))
    var task = Task(nursery^, CancellationToken())
    while a[][1] == 0 or b[][0] == 0:
        check(task.tick(), "callback children enter")
    release_a.notify()
    while b[][1] == 0:
        check(task.tick(), "first failure cancels sibling and enters withdrawal")
    check(not task.tick() and not task.done(), "entered sibling cleanup remains owned and parked")
    check(not right[].value().complete(success[Int, Int](42).outcome()), "canceled sibling rejects late producer")
    check(Bool(spawn.try_spawn(callback(Register(left.copy(), a.copy(), 1, False), Withdraw(a.copy(), release_a.copy(), False)))), "failure closes callback nursery")
    _ = task.tick()
    check(not task.tick(), "admission wake does not poll masked withdrawal")
    release_b.notify()
    while not task.done():
        check(task.tick(), "cleanup failure drains to join")
    var outcome = task^.finish()
    var error = outcome.take()._take_err()
    check(error.canceled, "sibling cancellation retained")
    var errors = error^.into_errors().into_list()
    check(len(errors) == 2 and errors[0] == 11 and errors[1] == 33, "callback and sibling cleanup errors in admission order")
    check(a[][1] == 2 and b[][1] == 2, "each withdrawal completes once")


def main():
    dynamic_success()
    parked_admission()
    canceled_scope()
    unopened_and_rejected()
    masking_and_unopened_cancel()
    failure_closes_admission()
    failure_drains_entered_callback()
    print("nurseries: runtime admission, bounded ownership, ordered results, scoped draining, masking, late handles")
