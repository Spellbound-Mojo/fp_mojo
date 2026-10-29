"""Behavioral probes for the private resumable foundation."""
from std.memory import ArcPointer
from std.time import monotonic, sleep
from std.os import abort
from fp.data import Result, Ok, Err, NonEmptyList
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure, ExitCase
from state_machine import Machine, ScopedMachine, CleanupMachine, Step, Wait, Signal, Task, Sleep, Scope, run, run_pair


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def success[T: Movable & Deinitable, E: Movable & Deinitable](var value: T) -> Step[T, E]:
    return Step[T, E].ready(Optional(Result[T, EffectFailure[E]](Ok(value^))))


@fieldwise_init
struct Failure(Movable):
    var code: Int
    var stats: ArcPointer[List[Int]]

    def __deinit__(deinit self):
        self.stats[][4] += 1


def failure[T: Movable & Deinitable](code: Int, stats: ArcPointer[List[Int]]) -> Step[T, Failure]:
    return Step[T, Failure].ready(Optional(Result[T, EffectFailure[Failure]](Err(
        EffectFailure(NonEmptyList(Failure(code, stats.copy())), False)))))


@fieldwise_init
struct Resource(Movable):
    var text: String
    var stats: ArcPointer[List[Int]]

    def __deinit__(deinit self):
        self.stats[][3] += 1


@fieldwise_init
struct Acquire(Machine):
    var stats: ArcPointer[List[Int]]
    var fail: Bool
    var cancel: Bool
    comptime Value = Resource
    comptime Error = Failure

    def poll(mut self, context: IOContext[Failure]) -> Step[Resource, Failure]:
        check(context._masked and not context.canceled(), "acquire must be masked")
        self.stats[][0] += 1
        if self.stats[][0] == 1:
            if self.cancel:
                context.request_cancel()
            return Step[Resource, Failure].pending(Wait.until(monotonic() + 1000000))
        if self.fail:
            return failure[Resource](11, self.stats)
        return success[Resource, Failure](Resource(String("scope owner"), self.stats.copy()))


@fieldwise_init
struct Use(ScopedMachine):
    var stats: ArcPointer[List[Int]]
    var fail: Bool
    var cancel: Bool
    comptime Input = Resource
    comptime Value = Int
    comptime Error = Failure

    def poll[p: ImmOrigin](mut self, ref[p] value: Resource, context: IOContext[Failure]) -> Step[Int, Failure]:
        check(value.text == "scope owner", "resource borrow must survive between polls")
        self.stats[][1] += 1
        if self.stats[][1] == 1:
            if self.cancel:
                context.request_cancel()
                var signal = Signal()
                return Step[Int, Failure].pending(Wait.changed(signal, signal.revision()))
            return Step[Int, Failure].pending(Wait())
        if self.fail:
            return failure[Int](22, self.stats)
        if context.canceled():
            return Step[Int, Failure].ready(None)
        return success[Int, Failure](42)


@fieldwise_init
struct Cleanup(CleanupMachine):
    var stats: ArcPointer[List[Int]]
    var fail: Bool
    var cancel: Bool
    var deadline: Int
    comptime Input = Resource
    comptime Error = Failure

    def poll[p: ImmOrigin](mut self, ref[p] value: Resource, exit: ExitCase[Failure], context: IOContext[Failure]) -> Step[NoneType, Failure]:
        check(value.text == "scope owner", "resource lives through release")
        check(self.stats[][3] == 0, "resource not destroyed early")
        check(context._masked and not context.canceled(), "cleanup must be masked")
        self.stats[][2] += 1
        if self.stats[][2] == 1:
            self.stats[][5] = Int(exit.is_error())
            self.stats[][6] = Int(exit.is_canceled())
            if exit.is_error():
                check(exit.failure().value().errors.first().code == 22, "exact error visible to cleanup")
            if self.cancel:
                context.request_cancel()
            self.deadline = monotonic() + 1000000
            return Step[NoneType, Failure].pending(Wait.until(self.deadline))
        check(monotonic() >= self.deadline, "cancellation cannot prematurely resume masked timer")
        if self.fail:
            return failure[NoneType](33, self.stats)
        var unit: NoneType = None
        return success[NoneType, Failure](unit)


def scope_case(stats: ArcPointer[List[Int]], af: Bool, ac: Bool, bf: Bool, bc: Bool, cf: Bool, cc: Bool) -> Int:
    var scope = Scope(Acquire(stats.copy(), af, ac), Use(stats.copy(), bf, bc), Cleanup(stats.copy(), cf, cc, 0))
    var outcome = run(scope^)
    check(stats[][0] == 2, "suspending acquire completes")
    check(stats[][1] == (0 if af or ac else 2), "unopened body skipped after cancellation")
    check(stats[][2] == (0 if af else 2), "cleanup entered and resumed once")
    check(stats[][3] == (0 if af else 1), "resource destroyed exactly once after cleanup")
    var expected_errors = 1 if af else Int(bf and not ac) + Int(cf)
    var canceled = ac or (not af and (bc or cc))
    if not af:
        check(stats[][5] == Int(bf and not ac), "cleanup sees original failure")
        check(stats[][6] == Int(ac or bc), "cleanup sees cancellation before release")
    if expected_errors:
        check(Bool(outcome) and outcome.value().is_err(), "failures must remain failures")
        var errors = outcome.take()._take_err()
        check(errors.canceled == canceled, "failure retains cancellation independently")
        var payloads = errors^.into_errors().into_list()
        check(len(payloads) == expected_errors, "error count")
        check(payloads[0].code == (11 if af else (22 if bf and not ac else 33)), "first error order")
        if expected_errors == 2:
            check(payloads[1].code == 33, "cleanup error comes last")
    elif canceled:
        check(not outcome, "cancellation without failure")
    else:
        check(Bool(outcome) and outcome.value().is_ok(), "success preserved")
        check(outcome.take()._take_ok() == 42, "body value preserved")
    return expected_errors


def scope_matrix():
    for af in range(2):
        for ac in range(2):
            for bf in range(2):
                for bc in range(2):
                    for cf in range(2):
                        for cc in range(2):
                            var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
                            var errors = scope_case(stats, Bool(af), Bool(ac), Bool(bf), Bool(bc), Bool(cf), Bool(cc))
                            check(stats[][4] == errors, "each move-only error destroyed exactly once")
    var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
    var token = CancellationToken()
    token.cancel()
    var scope = Scope(Acquire(stats.copy(), False, False), Use(stats.copy(), False, False), Cleanup(stats.copy(), False, False, 0))
    var canceled = run(scope^, token)
    check(not canceled and stats[][0] == 0, "already canceled scope stays unopened")
    print("scope matrix: 64 cases; unopened cancellation; exact destruction")


def move_parked_scopes():
    # Move after acquisition, during use, and during cleanup. There must be no
    # stored self-reference into the resource's previous location.
    for stage in range(3):
        var stats = ArcPointer(List[Int]([0, 0, 0, 0, 0, 0, 0]))
        var task = Task(Scope(Acquire(stats.copy(), False, False), Use(stats.copy(), False, False), Cleanup(stats.copy(), False, False, 0)), CancellationToken())
        while stats[][stage] < (2 if stage == 0 else 1):
            if not task.tick():
                sleep(0.001)
        var moved = task^
        moved.cancel()
        while not moved.done():
            if not moved.tick():
                sleep(0.001)
        var outcome = moved^.finish()
        check(not outcome, "cancellation after moving task")
        check(stats[][1] == (0 if stage == 0 else 2), "cancel between acquire and first use")
        check(stats[][2] == 2 and stats[][3] == 1, "moved task retains resource through cleanup")
    print("suspended scopes: moved at three lifecycle boundaries")


@fieldwise_init
struct Yielding(Machine):
    var trace: ArcPointer[List[Int]]
    var id: Int
    var remaining: Int
    comptime Value = Int
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if context.canceled():
            return Step[Int, Int].ready(None)
        self.trace[].append(self.id)
        if self.remaining == 0:
            return success[Int, Int](self.id)
        self.remaining -= 1
        return Step[Int, Int].pending(Wait())


@fieldwise_init
struct Waiter(Machine):
    var signal: Signal
    var state: ArcPointer[List[Int]]
    var notify_while_polling: Bool
    comptime Value = String
    comptime Error = String

    def poll(mut self, context: IOContext[String]) -> Step[String, String]:
        self.state[][1] += 1
        if context.canceled():
            return Step[String, String].ready(None)
        # Subscribe before observing the level: notifications between this
        # observation and parking cannot disappear.
        var revision = self.signal.revision()
        if self.state[][0] != 0:
            return success[String, String](String("woken"))
        if self.notify_while_polling:
            self.state[][0] = 1
            self.signal.notify()
        return Step[String, String].pending(Wait.changed(self.signal, revision))


@fieldwise_init
struct Producer(Machine):
    var signal: Signal
    var state: ArcPointer[List[Int]]
    var remaining: Int
    comptime Value = Int
    comptime Error = Int

    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        if self.remaining:
            self.remaining -= 1
            return Step[Int, Int].pending(Wait())
        self.state[][0] = 1
        self.signal.notify()
        return success[Int, Int](7)


def scheduler_cases():
    var trace = ArcPointer(List[Int]())
    var pair = run_pair(Yielding(trace.copy(), 1, 3), Yielding(trace.copy(), 2, 3), CancellationToken(), CancellationToken())
    check(Bool(pair[0]) and Bool(pair[1]), "both tasks complete")
    check(len(trace[]) == 8, "each task takes four steps")
    for i in range(8):
        check(trace[][i] == 1 + i % 2, "ready tasks progress in round-robin order")
    var signal = Signal()
    var state = ArcPointer(List[Int]([0, 0]))
    var mixed = run_pair(Waiter(signal.copy(), state.copy(), False), Producer(signal.copy(), state.copy(), 1000), CancellationToken(), CancellationToken())
    check(state[][1] == 2, "parked task not polled on every scheduler iteration")
    check(mixed[0].take()._take_ok() == "woken", "heterogeneous String result")
    check(mixed[1].take()._take_ok() == 7, "heterogeneous Int result")
    var raced_state = ArcPointer(List[Int]([0, 0]))
    var raced = run(Waiter(Signal(), raced_state.copy(), True))
    check(Bool(raced) and raced_state[][1] == 2, "notification before parking is retained")
    var ready_state = ArcPointer(List[Int]([1, 0]))
    var ready = run(Waiter(Signal(), ready_state.copy(), False))
    check(Bool(ready) and ready_state[][1] == 1, "already ready condition needs no notification")
    var canceled_state = ArcPointer(List[Int]([0, 0]))
    var task = Task(Waiter(Signal(), canceled_state.copy(), False), CancellationToken())
    check(task.tick() and not task.done(), "waiter parks")
    check(not task.tick(), "unchanged signal stays parked")
    task.cancel()
    check(task.tick() and task.done(), "cancel resumes parked task")
    var canceled = task^.finish()
    check(not canceled and canceled_state[][1] == 2, "cancel observed by machine")
    var start = monotonic()
    var slept = run(Sleep[Int](2000000))
    check(Bool(slept) and monotonic() - start >= 2000000, "timer waits for its deadline")
    var many = ArcPointer(List[Int]())
    var result = run(Yielding(many.copy(), 9, 100000))
    check(Bool(result) and len(many[]) == 100001, "100000 suspensions complete without recursive driver calls")
    print("scheduler: fairness, heterogeneous types, parking, wake race, cancellation, timer, 100000 yields")


@fieldwise_init
struct Borrowed[o: ImmOrigin](Machine):
    var owner: Pointer[List[Int], Self.o]
    var phase: Int
    var fail: Bool
    comptime Value = Span[Int, Self.o]
    comptime Error = Span[Int, Self.o]

    def poll(mut self, context: IOContext[Self.Error]) -> Step[Self.Value, Self.Error]:
        if self.phase == 0:
            self.phase = 1
            return Step[Self.Value, Self.Error].pending(Wait())
        if self.fail:
            return Step[Self.Value, Self.Error].ready(Optional(Result[Self.Value, EffectFailure[Self.Error]](Err(
                EffectFailure(NonEmptyList(Span(self.owner[])), False)))))
        return success[Self.Value, Self.Error](Span(self.owner[]))


def main():
    scheduler_cases()
    scope_matrix()
    move_parked_scopes()
    var owner = List[Int]([13, 17])
    var outcome = run(Borrowed(Pointer(to=owner), 0, False))
    var view = outcome.take()._take_ok()
    check(view[1] == 17, "external capture and result retain native origins")
    var failed = run(Borrowed(Pointer(to=owner), 0, True))
    var error = failed.take()._take_err()
    check(error.errors.first()[0] == 13, "borrowed errors retain native origins")
    print("borrowed captures: passed")
