"""One public typed loop repeatedly owns callbacks and suspending withdrawal."""
from std.memory import ArcPointer
from fp.algebra import tail_rec_m, map
from fp.callables import Unary, OnceUnary
from fp.data import ControlFlow, Continue, Break
from fp.effects import CancellationToken
from fp.effects.async_runtime import Async, Clock, Driver, Duration, Instant, Completion, Callback, TimeoutTo, Pure, callback, timeout_to, pure
from fp.effects.async_runtime.protocols import Machine, Context, Step, Wait
from fp._internal.cells import _lock_metadata
from support import Window, check, success, advance


struct Counts(Movable):
    var created: Int
    var dropped: Int
    def __init__(out self):
        self.created = 0
        self.dropped = 0


struct Payload(Movable):
    var value: Int
    var counts: ArcPointer[Counts]
    def __init__(out self, value: Int, counts: ArcPointer[Counts]):
        self.value = value
        self.counts = counts.copy()
        counts[].created += 1
    def __deinit__(deinit self):
        self.counts[].dropped += 1


struct Host(Movable):
    var window: Window
    var payloads: ArcPointer[Counts]
    var guards: ArcPointer[Counts]
    var current: Optional[Completion[Payload, Int]]
    var history: List[Optional[Completion[Payload, Int]]]
    var iteration: Int
    var completed: Int
    var withdrawals: Int
    var delivered: Bool
    def __init__(out self, window: Window):
        self.window = window.copy()
        self.payloads = ArcPointer(Counts())
        self.guards = ArcPointer(Counts())
        self.current = None
        self.history = List[Optional[Completion[Payload, Int]]]()
        for _ in range(4):
            self.history.append(None)
        self.iteration = 0
        self.completed = 0
        self.withdrawals = 0
        self.delivered = False


def retired(completion: Completion[Payload, Int], counts: ArcPointer[Counts]):
    check(not completion.complete(success(Payload(-999, counts))), "late payload rejected")
    var guard = _lock_metadata(completion._signal._cell)
    check(guard.cell[].slot.value().active == 0, "closed callback retains no live subscription")
    check(len(guard.cell[].slot.value().entries) <= 1, "callback signal storage bounded")


@fieldwise_init
struct Register(OnceUnary):
    var host: ArcPointer[Host]
    var iteration: Int
    comptime Arg = Completion[Payload, Int]
    comptime Out = NoneType
    def call_once(deinit self, var done: Self.Arg) -> NoneType:
        self.host[].iteration = self.iteration
        self.host[].delivered = False
        if self.iteration % 3 == 0:
            check(done.complete(success(Payload(self.iteration, self.host[].payloads))), "completion before subscription accepted")
            self.host[].delivered = True
        self.host[].current = Optional(done^)
        return None


@fieldwise_init
struct Withdraw(Machine):
    var host: ArcPointer[Host]
    var guard: Payload
    var pause: Duration
    var deadline: Optional[Instant]
    comptime Value = NoneType
    comptime Error = Int
    comptime Family = Async[Int]
    def poll(mut self, context: Context[Int]) -> Step[NoneType, Int]:
        check(context._masked and not context.canceled(), "withdrawal stays masked")
        if not self.deadline:
            self.deadline = Optional(context.now() + self.pause)
        if context.now() < self.deadline.value():
            return .pending(Wait.until(self.deadline.value()))
        self.host[].withdrawals += 1
        var unit: NoneType = None
        return .ready(success(unit))


@fieldwise_init
struct Advance(OnceUnary):
    var host: ArcPointer[Host]
    var iteration: Int
    comptime Arg = Payload
    comptime Out = ControlFlow[Int, Int]
    def call_once(deinit self, var value: Payload) -> Self.Out:
        var expected = -self.iteration - 1 if self.iteration % 3 == 2 else self.iteration
        check(value.value == expected, "completion or timeout chooses expected owned value")
        check(self.host[].withdrawals == self.iteration + 1, "selected outcome waits for withdrawal")
        self.host[].completed += 1
        var next = self.iteration + 1
        if self.host[].window.more(next):
            return Self.Out(Continue(next))
        return Self.Out(Break(next))


@fieldwise_init
struct Factory(Unary):
    var host: ArcPointer[Host]
    var timeout: Duration
    var pause: Duration
    comptime Arg = Int
    comptime Body = TimeoutTo[Callback[Register, Withdraw], Pure[Payload, Int]]
    comptime Out = Async[Int].Mapped[Self.Body, Advance]
    def call(self, var iteration: Int) -> Self.Out:
        check(self.host[].payloads[].created == self.host[].payloads[].dropped, "previous step releases all payloads before next construction")
        check(self.host[].guards[].created == self.host[].guards[].dropped, "withdrawal capture destroyed before next step")
        if self.host[].current:
            retired(self.host[].current.value(), self.host[].payloads)
            self.host[].history[(iteration - 1) % 4] = Optional(self.host[].current.take())
        var body = callback(Register(self.host.copy(), iteration),
            Withdraw(self.host.copy(), Payload(iteration, self.host[].guards), self.pause.copy(), None))
        var selected = timeout_to(body^, self.timeout, pure[Int](Payload(-iteration - 1, self.host[].payloads)))
        return map[Async[Int]](Advance(self.host.copy(), iteration), selected^)


def main() raises:
    var window = Window()
    var host = ArcPointer(Host(window))
    var clock = Clock.manual(Int.MAX)
    var driver = Driver(tail_rec_m[Async[Int]](Factory(host.copy(), Duration.nanoseconds(10), Duration.nanoseconds(2)), 0), CancellationToken(), clock)
    var runtime = driver._driver.task.context._runtime.value().copy()
    var progress = driver.poll()
    var polls = 0
    var node_capacity = 0
    var nodes = 0
    var timers_peak = 0
    while not progress.completed:
        polls += 1
        var delivered_now = False
        if host[].current and not host[].delivered and host[].iteration % 3 == 1:
            check(host[].current.value().complete(success(Payload(host[].iteration, host[].payloads))), "parked callback accepts owned value")
            check(not host[].current.value().complete(success(Payload(-888, host[].payloads))), "duplicate completion rejects and destroys payload")
            host[].delivered = True
            delivered_now = True
        # A host notification makes the previous idle observation stale. Drive
        # it before advancing time, otherwise the harness creates a timeout tie.
        if not progress.runnable and not delivered_now:
            check(Bool(progress.deadline), "pending callback or withdrawal exposes a deadline")
            advance(clock, progress.deadline.value())
        var guard = _lock_metadata(runtime._cell)
        ref state = guard.cell[].slot.value()
        nodes = max(nodes, len(state.nodes))
        timers_peak = max(timers_peak, len(state.timers))
        check(len(state.nodes) <= 64 and len(state.timers) <= 2 * state.live_timers + 33, "bounded registry and timer storage during persistent loop")
        if host[].completed >= 16:
            if node_capacity == 0:
                node_capacity = state.nodes.capacity()
            check(state.nodes.capacity() == node_capacity, "registry capacity stays fixed after warmup")
        _ = guard^
        progress = driver.poll()
    var outcome = driver^.finish()
    check(outcome.take()._take_ok() == host[].completed, "typed loop returns exact completed count")
    retired(host[].current.value(), host[].payloads)
    for prior in host[].history:
        if prior:
            retired(prior.value(), host[].payloads)
    check(host[].payloads[].created == host[].payloads[].dropped, "all accepted, fallback and rejected payloads destroyed exactly once")
    check(host[].guards[].created == host[].guards[].dropped and host[].withdrawals == host[].completed, "all entered withdrawal captures retired")
    var guard = _lock_metadata(runtime._cell)
    check(guard.cell[].slot.value().active == 0 and guard.cell[].slot.value().live_timers == 0, "root finish retires all registrations")
    print("stress lifecycle", "cycles=" + String(host[].completed), "elapsed_ns=" + String(window.elapsed()),
          "nodes=" + String(nodes), "node_capacity=" + String(node_capacity), "timers_peak=" + String(timers_peak),
          "payloads=" + String(host[].payloads[].created), "drops=" + String(host[].payloads[].dropped),
          "withdrawals=" + String(host[].withdrawals), "polls=" + String(polls), "active=0", "live_timers=0", flush=True)
