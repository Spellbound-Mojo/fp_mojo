"""A bounded callback worker pipeline driven by explicit host events and time."""
from foundation import at
from std.memory import ArcPointer
from fp.callables import OnceUnary
from fp.data import Result, Err, NonEmptyList
from fp.effects import CancellationToken, IOContext, EffectFailure, ExitCase
from fp._internal.cells import _lock_metadata
from state_machine import Machine, ScopedMachine, CleanupMachine, Step, Wait, Signal, Completion, Callback, Scope, Pure, Timeout, Nursery, Queue, Semaphore, Clock, Driver, callback, pure, bind, both, timeout_after as timeout_to
from state_machine.coordination import _Offer
from foundation import check, success
from async_coordination import value


struct Host(Movable):
    var completions: List[Optional[Completion[Int, Int]]]
    var gates: List[Signal]
    var withdrawal: List[Int]
    var delivered: List[Bool]
    var holds: List[Int]
    var created: List[Int]
    var dropped: List[Int]
    var fallbacks: List[Int]
    var active: Int
    var peak: Int
    var mode: Int
    def __init__(out self, mode: Int):
        self.completions = List[Optional[Completion[Int, Int]]]()
        self.gates = List[Signal]()
        self.withdrawal = List[Int]()
        self.delivered = List[Bool]()
        self.holds = List[Int]()
        self.created = List[Int]()
        self.dropped = List[Int]()
        self.fallbacks = List[Int]()
        self.active = 0
        self.peak = 0
        self.mode = mode
        for _ in range(6):
            self.completions.append(None)
            self.gates.append(Signal())
            self.withdrawal.append(0)
            self.delivered.append(False)
            self.holds.append(0)
            self.created.append(0)
            self.dropped.append(0)
            self.fallbacks.append(0)


struct Request(Movable):
    var id: Int
    var host: ArcPointer[Host]
    def __init__(out self, id: Int, host: ArcPointer[Host]):
        self.id = id
        self.host = host.copy()
        self.host[].created[id] += 1
    def __deinit__(deinit self):
        self.host[].dropped[self.id] += 1


@fieldwise_init
struct Register(OnceUnary):
    var host: ArcPointer[Host]
    var id: Int
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType
    def call_once(deinit self, var done: Self.Arg) -> NoneType:
        check(not self.host[].completions[self.id], "callback registered once")
        self.host[].completions[self.id] = Optional(done^)
        self.host[].active += 1
        if self.host[].active > self.host[].peak:
            self.host[].peak = self.host[].active
        check(self.host[].active <= 2, "permits bound active callback work")
        return None


@fieldwise_init
struct Withdraw(Machine):
    var host: ArcPointer[Host]
    var id: Int
    comptime Value = NoneType
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[NoneType, Int]:
        check(context._masked and not context.canceled(), "withdrawal remains masked")
        if self.host[].withdrawal[self.id] == 0:
            self.host[].withdrawal[self.id] = 1
            var wait = Wait.changed(self.host[].gates[self.id], self.host[].gates[self.id].revision())
            wait._interruptible = False
            return .pending(wait^)
        check(self.host[].withdrawal[self.id] == 1, "withdrawal resumes once")
        self.host[].withdrawal[self.id] = 2
        if self.host[].mode == 2 and self.id == 1:
            return .ready(Optional(Result[NoneType, EffectFailure[Int]](Err(EffectFailure(NonEmptyList(73), False)))))
        var unit: NoneType = None
        return success[NoneType, Int](unit)


@fieldwise_init
struct Use(ScopedMachine):
    var program: Callback[Register, Withdraw]
    comptime Input = Request
    comptime Value = Int
    comptime Error = Int
    def poll[o: ImmOrigin](mut self, ref[o] request: Request, context: IOContext[Int]) -> Step[Int, Int]:
        check(request.host[].dropped[request.id] == 0, "request lives through body and withdrawal")
        return self.program.poll(context)


@fieldwise_init
struct Release(CleanupMachine):
    comptime Input = Request
    comptime Error = Int
    def poll[o: ImmOrigin](mut self, ref[o] request: Request, exit: ExitCase[Int], context: IOContext[Int]) -> Step[NoneType, Int]:
        check(context._masked, "resource release is masked")
        if request.host[].completions[request.id]:
            check(request.host[].withdrawal[request.id] == 2, "request released after callback withdrawal")
            request.host[].active -= 1
        var unit: NoneType = None
        return success[NoneType, Int](unit)


@fieldwise_init
struct Fallback(Machine):
    var host: ArcPointer[Host]
    var id: Int
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        check(self.host[].dropped[self.id] == 1 and self.host[].withdrawal[self.id] == 2, "fallback starts after request and callback release")
        self.host[].fallbacks[self.id] += 1
        return success[Int, Int](-self.id - 1)


@fieldwise_init
struct Start(OnceUnary):
    comptime Arg = Request
    comptime Out = Timeout[Scope[Pure[Request, Int], Use, Release], Fallback]
    def call_once(deinit self, var request: Request) -> Self.Out:
        var id = request.id
        var host = request.host.copy()
        var body = callback(Register(host.copy(), id), Withdraw(host.copy(), id))
        return timeout_to(Scope(pure[Int](request^), Use(body^), Release()), 10, Fallback(host.copy(), id))


struct Producer(Machine):
    var queue: Queue[Request]
    var host: ArcPointer[Host]
    var next: Int
    var pending: Optional[_Offer[Request, Int]]
    comptime Value = NoneType
    comptime Error = Int
    def __init__(out self, queue: Queue[Request], host: ArcPointer[Host]):
        self.queue = queue.copy()
        self.host = host.copy()
        self.next = 0
        self.pending = None
    def poll(mut self, context: IOContext[Int]) -> Step[NoneType, Int]:
        if not self.pending:
            if context.canceled():
                return .ready(None)
            if self.next == 6:
                var unit: NoneType = None
                return success[NoneType, Int](unit)
            self.pending = Optional(self.queue.offer[Int](Request(self.next, self.host)))
        var step = self.pending.value().poll(context)
        if not step._completed:
            return step^
        var outcome = step^._outcome()
        self.pending = None
        if not outcome or outcome.value().is_err():
            return .ready(outcome^)
        self.next += 1
        return .pending(Wait())


def cycle(mode: Int) raises:
    var queue = Queue[Request](2)
    var semaphore = Semaphore(2)
    var host = ArcPointer(Host(mode))
    var clock = Clock.manual()
    comptime Worker = type_of(semaphore.with_permit(bind(queue.take[Int](), Start())))
    var nursery = Nursery[Worker](6)
    var spawn = nursery.spawner()
    for _ in range(6):
        check(not spawn.try_spawn(semaphore.with_permit(bind(queue.take[Int](), Start()))), "worker admitted")
    spawn.close()
    var driver = Driver(both(Producer(queue, host), nursery^), CancellationToken(), clock)
    var progress = driver.poll(7)
    var timed = False
    var canceled = False
    var rounds = 0
    while not progress.completed:
        rounds += 1
        check(rounds < 2000, "bounded host progress")
        if mode == 3 and host[].active == 2 and not canceled:
            driver.cancel()
            canceled = True
        for id in range(6):
            if host[].completions[id] and not host[].delivered[id] and not canceled:
                if mode == 1 and id == 1:
                    var others_drained = True
                    for other in range(6):
                        if other != 1 and host[].dropped[other] != 1:
                            others_drained = False
                    if not timed and others_drained:
                        clock.advance_to(at(10))
                        timed = True
                else:
                    _ = host[].completions[id].value().complete(success[Int, Int](id + 100)._outcome())
                    host[].delivered[id] = True
            if host[].withdrawal[id] == 1:
                check(host[].dropped[id] == 0 and host[].fallbacks[id] == 0, "suspending withdrawal retains request and defers fallback")
                host[].holds[id] += 1
                if host[].holds[id] == 3:
                    host[].gates[id].notify()
        progress = driver.poll(7)
    check(progress.completed, "host exits only after full draining")
    var runtime = driver.task.context._runtime.value().copy()
    var outcome = driver^.finish()
    if mode == 2:
        var failed = outcome.take()._take_err()
        check(failed.errors.first() == 73, "cleanup error survives structured pipeline")
    elif mode == 3:
        check(canceled and not outcome, "external cancellation drains pipeline")
    else:
        var results = outcome.take()._take_ok()
        check(len(results[1]) == 6, "every worker returns one result")
        var total = 0
        for result in results[1]:
            total += result
        check(total == (512 if mode == 1 else 615), "normal and fallback results preserved")
        check(host[].fallbacks[1] == Int(mode == 1), "only timed-out work enters fallback")
    check(value(semaphore.available[Int]()) == 2 and host[].active == 0 and host[].peak == 2, "all permits restored after full draining")
    _ = queue^
    for id in range(6):
        check(host[].created[id] == host[].dropped[id], "every created request destroyed exactly once")
        if host[].completions[id]:
            check(not host[].completions[id].value().complete(success[Int, Int](999)._outcome()), "late callbacks rejected")
            var subscription = _lock_metadata(host[].completions[id].value().signal._cell)
            check(subscription.cell[].slot.value().active == 0, "callback subscription retired")
        var gate = _lock_metadata(host[].gates[id]._cell)
        check(gate.cell[].slot.value().active == 0, "withdrawal subscription retired")
    var guard = _lock_metadata(runtime._cell)
    check(guard.cell[].slot.value().active == 0 and guard.cell[].slot.value().live_timers == 0, "all task and timer registrations retired")
    check(len(guard.cell[].slot.value().nodes) <= 256, "registry storage bounded by finite workload")


def main() raises:
    for _ in range(8):
        for mode in range(4):
            cycle(mode)
    print("workload: 32 bounded worker cycles; completion, timeout, cleanup failure, cancellation, exact ownership, retired registrations")
