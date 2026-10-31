"""Gate timings for S8 against the nightly baseline (build at -O3; not qualified).

The same file builds against both trees: it uses only API both share. Each
case prints the median of 7 runs with the min-max spread, per operation.

- `rtt`: an IO.async registration completed by a resident OS thread, through to
  its continuation running on the polling thread; a round trip per round.
- `join`: start a child that finishes at once and join it, so the join races
  the child's completion within one poll.
- `starts`: one fiber starts 1,000 fibers that wait forever, then finishes, so
  its scope cancels and drains them; per fiber.
- `supervise`: the same 1,000 fibers started through a supervisor, canceled by
  its release; per fiber.
- `adopt`: OS threads adopt fiber records into one scope, the start path's
  list (`_Scope.adopt`), 1 and 4 threads; per adoption. Records are made
  before timing.
- `adopt_hot`: one thread makes each record and adopts it at once, as a start
  does; per record and adoption.

Run with a case name, or with none for every case. Compare only runs taken back
to back.
"""
from std.atomic import Atomic, Ordering
from std.memory import ArcPointer
from std.os import abort
from std.sys import argv
from std.time import perf_counter_ns, sleep
from fp.callables import OnceUnary
from fp.data import Result, Ok
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure, Fiber as Thread, unsafe_start, ReaderAction
from fp.effects import IO as SyncIO
from fp.effects.async_runtime import IO, Fiber, Completion, Driver, Supervisor, run
from fp.effects._async.fibers import _FiberRecord, _Scope

comptime RUNS = 7


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def spread(var samples: List[Float64]) -> String:
    sort(samples)
    return String(samples[len(samples) // 2], " [", samples[0], "-", samples[len(samples) - 1], "]")


# ---- rtt: a foreign completion through to its continuation

struct Mail(Movable):
    """A one-slot mailbox between the polling thread and the completer."""
    var flag: Atomic[Int]
    var slot: Optional[Completion[Int, Int]]

    def __init__(out self):
        self.flag = Atomic(0)
        self.slot = None


@fieldwise_init
struct Completer(ReaderAction):
    var mail: ArcPointer[Mail]
    comptime Family = SyncIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        while True:
            var flag = self.mail[].flag.load[ordering=Ordering.ACQUIRE]()
            if flag == 2:
                return Outcome[NoneType, Error](None)
            if flag == 1:
                var done = self.mail[].slot.take()
                self.mail[].flag.store[ordering=Ordering.RELEASE](0)
                _ = done.complete(Optional(Result[Int, EffectFailure[Int]](Ok(1))))


@fieldwise_init
struct Post(OnceUnary):
    var mail: ArcPointer[Mail]
    comptime Arg = Completion[Int, Int]
    comptime Out = NoneType

    def call_once(deinit self, var done: Completion[Int, Int]) -> NoneType:
        self.mail[].slot = Optional(done^)
        self.mail[].flag.store[ordering=Ordering.RELEASE](1)
        return None


@fieldwise_init
struct Rounds(OnceUnary):
    var mail: ArcPointer[Mail]
    var left: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        return IO[Int, Int].`async`(Post(self.mail.copy()), IO[NoneType, Int].pure(None)).map(Plus(total)).flat_map(Rounds(self.mail.copy(), self.left - 1))


@fieldwise_init
struct Plus(OnceUnary):
    var base: Int
    comptime Arg = Int
    comptime Out = Int

    def call_once(deinit self, var value: Int) -> Int:
        return self.base + value


def rtt() raises:
    comptime rounds = 20_000
    var samples = List[Float64]()
    for _ in range(RUNS):
        var mail = ArcPointer(Mail())
        var completer = unsafe_start(Completer(mail.copy()))
        var start = perf_counter_ns()
        var driver = Driver(IO[Int, Int].pure(0).flat_map(Rounds(mail.copy(), rounds)))
        while not driver.poll().completed:
            pass
        var outcome = driver^.finish()
        var elapsed = Int(perf_counter_ns() - start)
        check(Bool(outcome) and outcome.take()._take_ok() == rounds, "every round completed")
        mail[].flag.store[ordering=Ordering.RELEASE](2)
        _ = completer^.join()
        samples.append(Float64(elapsed) / Float64(rounds))
    print("rtt ns_per_round=" + spread(samples^))


# ---- join: start a finished child and join it

@fieldwise_init
struct Cycle(OnceUnary):
    var left: Int
    comptime Arg = Int
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var total: Int) -> IO[Int, Int]:
        if self.left == 0:
            return IO[Int, Int].pure(total)
        return IO[Int, Int].pure(1).start().flat_map(JoinOne(total, self.left))


@fieldwise_init
struct JoinOne(OnceUnary):
    var total: Int
    var left: Int
    comptime Arg = Fiber[Int, Int]
    comptime Out = IO[Int, Int]

    def call_once(deinit self, var fiber: Fiber[Int, Int]) -> IO[Int, Int]:
        return fiber^.join_with_never().map(Plus(self.total)).flat_map(Cycle(self.left - 1))


def join() raises:
    comptime cycles = 100_000
    var samples = List[Float64]()
    for _ in range(RUNS):
        var start = perf_counter_ns()
        var outcome = run(IO[Int, Int].pure(0).flat_map(Cycle(cycles)))
        var elapsed = Int(perf_counter_ns() - start)
        check(Bool(outcome) and outcome.take()._take_ok() == cycles, "every join took its child")
        samples.append(Float64(elapsed) / Float64(cycles))
    print("join ns_per_cycle=" + spread(samples^))


# ---- starts: 1,000 fibers from one fiber, or through a supervisor

@fieldwise_init
struct StartMany(OnceUnary):
    var left: Int
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        if self.left == 0:
            return IO[NoneType, Int].pure(None)
        return IO[NoneType, Int].never().start().flat_map(DropThen(self.left - 1))


@fieldwise_init
struct DropThen(OnceUnary):
    var left: Int
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[NoneType, Int]:
        return IO[NoneType, Int].pure(None).flat_map(StartMany(self.left))


@fieldwise_init
struct SuperviseMany(OnceUnary):
    var left: Int
    comptime Arg = Supervisor[Int]
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var supervisor: Supervisor[Int]) -> IO[NoneType, Int]:
        return IO[NoneType, Int].pure(None).flat_map(SuperviseNext(supervisor^, self.left))


@fieldwise_init
struct SuperviseNext(OnceUnary):
    var supervisor: Supervisor[Int]
    var left: Int
    comptime Arg = NoneType
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var unit: NoneType) -> IO[NoneType, Int]:
        if self.left == 0:
            return IO[NoneType, Int].pure(None)
        var next = SuperviseNext(self.supervisor.copy(), self.left - 1)
        return self.supervisor.supervise(IO[NoneType, Int].never()).flat_map(DropSupervised(next^))


@fieldwise_init
struct DropSupervised(OnceUnary):
    var next: SuperviseNext
    comptime Arg = Fiber[NoneType, Int]
    comptime Out = IO[NoneType, Int]

    def call_once(deinit self, var fiber: Fiber[NoneType, Int]) -> IO[NoneType, Int]:
        return IO[NoneType, Int].pure(None).flat_map(self.next^)


def starts[supervised: Bool]() raises:
    comptime fibers = 1000
    comptime repeats = 20
    var samples = List[Float64]()
    for _ in range(RUNS):
        var start = perf_counter_ns()
        for _ in range(repeats):
            var outcome: Outcome[NoneType, Int]
            comptime if supervised:
                outcome = run(Supervisor[Int].scoped(SuperviseMany(fibers)))
            else:
                outcome = run(IO[NoneType, Int].pure(None).flat_map(StartMany(fibers)))
            check(Bool(outcome) and outcome.value().is_ok(), "the starter completes after draining")
        samples.append(Float64(Int(perf_counter_ns() - start)) / Float64(fibers * repeats))
    print("supervise" if supervised else "starts", "ns_per_fiber=" + spread(samples^))


# ---- adopt: OS threads adopting into one scope

struct AdoptRig(Movable):
    var scope: _Scope[Int]
    var ready: Atomic[Int]
    var go: Atomic[Int]

    def __init__(out self):
        self.scope = _Scope[Int]()
        self.ready = Atomic(0)
        self.go = Atomic(0)


@fieldwise_init
struct Adopter(ReaderAction):
    var rig: ArcPointer[AdoptRig]
    var records: List[ArcPointer[_FiberRecord[Int]]]
    comptime Family = SyncIO[Error]
    comptime Env = IOContext[Error]
    comptime Value = NoneType
    comptime Out[o: ImmOrigin] = Outcome[NoneType, Error]

    def run[o: ImmOrigin](deinit self, ref[o] context: Self.Env) -> Self.Out[o]:
        _ = self.rig[].ready.fetch_add(1)
        while self.rig[].go.load[ordering=Ordering.ACQUIRE]() == 0:
            pass
        for index in range(len(self.records)):
            _ = self.rig[].scope.adopt(self.records[index])
        return Outcome[NoneType, Error](None)


def adopt(threads: Int) raises:
    comptime total = 200_000
    var samples = List[Float64]()
    for _ in range(RUNS):
        var rig = ArcPointer(AdoptRig())
        var workers = List[Thread[Adopter]]()
        for _ in range(threads):
            var records = List[ArcPointer[_FiberRecord[Int]]]()
            for _ in range(total // threads):
                records.append(ArcPointer(_FiberRecord[Int]()))
            workers.append(unsafe_start(Adopter(rig.copy(), records^)))
        while rig[].ready.load() < threads:
            sleep(0.0001)
        var start = perf_counter_ns()
        rig[].go.store[ordering=Ordering.RELEASE](1)
        while workers:
            _ = workers.pop().join()
        var elapsed = Int(perf_counter_ns() - start)
        check(rig[].scope.count() == (total // threads) * threads, "every child is counted")
        rig[].scope.cancel_children()
        samples.append(Float64(elapsed) / Float64((total // threads) * threads))
    print("adopt threads=" + String(threads), "ns_per_adoption=" + spread(samples^))


def adopt_hot() raises:
    """One thread creates each record just before adopting it, as a start does."""
    comptime total = 200_000
    var samples = List[Float64]()
    for _ in range(RUNS):
        var scope = _Scope[Int]()
        var start = perf_counter_ns()
        for _ in range(total):
            _ = scope.adopt(ArcPointer(_FiberRecord[Int]()))
        var elapsed = Int(perf_counter_ns() - start)
        check(scope.count() == total, "every child is counted")
        scope.cancel_children()
        samples.append(Float64(elapsed) / Float64(total))
    print("adopt_hot threads=1 ns_per_record_and_adoption=" + spread(samples^))


def main() raises:
    var selected = String(argv()[1]) if len(argv()) > 1 else String("all")
    if selected == "all" or selected == "rtt":
        rtt()
    if selected == "all" or selected == "join":
        join()
    if selected == "all" or selected == "starts":
        starts[False]()
    if selected == "all" or selected == "supervise":
        starts[True]()
    if selected == "all" or selected == "adopt":
        adopt(1)
        adopt(4)
    if selected == "all" or selected == "adopt_hot":
        adopt_hot()
