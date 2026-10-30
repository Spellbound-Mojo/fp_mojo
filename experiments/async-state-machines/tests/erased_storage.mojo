"""Machines of different types behind one carrier, with exact move-only ownership."""
from std.memory import ArcPointer
from fp.effects import IOContext, CancellationToken, Outcome
from fp.callables import OnceUnary
from fp.effects._async.engine import IO, Fiber
from state_machine import ErasedMachine, Machine, Step, Wait, Task, run, both
from foundation import check, success, failure, Failure, Borrowed

# Stats slots: 0 machines destroyed, 1 tokens destroyed, 2 pending polls,
# 4 failures destroyed (foundation.Failure).
comptime MACHINES = 0
comptime TOKENS = 1
comptime PENDING = 2
comptime FAILURES = 4


def new_stats() -> ArcPointer[List[Int]]:
    return ArcPointer(List[Int]([0, 0, 0, 0, 0]))


@fieldwise_init
struct Token(Movable):
    var id: Int
    var stats: ArcPointer[List[Int]]

    def __deinit__(deinit self):
        self.stats[][TOKENS] += 1


@fieldwise_init
struct Immediate(Machine):
    var id: Int
    var stats: ArcPointer[List[Int]]
    comptime Value = Token
    comptime Error = Failure

    def __deinit__(deinit self):
        self.stats[][MACHINES] += 1

    def poll(mut self, context: IOContext[Failure]) -> Step[Token, Failure]:
        return success[Token, Failure](Token(self.id, self.stats.copy()))


@fieldwise_init
struct Countdown(Machine):
    var id: Int
    var remaining: Int
    var label: String
    var stats: ArcPointer[List[Int]]
    comptime Value = Token
    comptime Error = Failure

    def __deinit__(deinit self):
        self.stats[][MACHINES] += 1

    def poll(mut self, context: IOContext[Failure]) -> Step[Token, Failure]:
        if context.canceled():
            return .ready(None)
        if self.remaining > 0:
            self.remaining -= 1
            self.stats[][PENDING] += 1
            return .pending(Wait())
        check(self.label == "countdown", "erased machine state survives suspension")
        return success[Token, Failure](Token(self.id, self.stats.copy()))


@fieldwise_init
struct Failing(Machine):
    var code: Int
    var stats: ArcPointer[List[Int]]
    comptime Value = Token
    comptime Error = Failure

    def __deinit__(deinit self):
        self.stats[][MACHINES] += 1

    def poll(mut self, context: IOContext[Failure]) -> Step[Token, Failure]:
        return failure[Token](self.code, self.stats)


comptime Erased = ErasedMachine[Token, Failure]


def separate_runs():
    var stats = new_stats()
    var programs = List[Erased]()
    programs.append(Erased(Immediate(1, stats.copy())))
    programs.append(Erased(Countdown(2, 3, String("countdown"), stats.copy())))
    programs.append(Erased(Failing(41, stats.copy())))
    var first = run(programs.pop(0))
    check(first.take()._take_ok().id == 1, "immediate success")
    var second = run(programs.pop(0))
    check(second.take()._take_ok().id == 2 and stats[][PENDING] == 3, "suspended success")
    var third = run(programs.pop(0))
    var errors = third.take()._take_err().into_errors().into_list()
    check(len(errors) == 1 and errors[0].code == 41, "move-only failure crosses the carrier")
    _ = errors^
    check(stats[][MACHINES] == 3 and stats[][TOKENS] == 2 and stats[][FAILURES] == 1, "each payload destroyed once")


def unopened_and_moved():
    var stats = new_stats()
    var programs = List[Erased]()
    programs.append(Erased(Countdown(5, 2, String("countdown"), stats.copy())))
    programs.append(Erased(Immediate(6, stats.copy())))
    var moved = programs.pop()
    check(stats[][MACHINES] == 0, "moving an erased machine destroys nothing")
    _ = moved^
    check(stats[][MACHINES] == 1, "unopened erased machine destroyed once")
    programs.clear()
    check(stats[][MACHINES] == 2 and stats[][TOKENS] == 0 and stats[][PENDING] == 0, "discarded without polling")


def child(index: Int, stats: ArcPointer[List[Int]]) -> IO[Token, Failure]:
    if index % 2 == 0:
        return IO[Token, Failure].lift(Erased(Countdown(index, index, String("countdown"), stats.copy())))
    return IO[Token, Failure].lift(Erased(Immediate(index, stats.copy())))


@fieldwise_init
struct StartAll(OnceUnary):
    """Start each heterogeneous child as a fiber, then join them in start order."""
    var next: Int
    var stats: ArcPointer[List[Int]]
    var handles: List[Fiber[Token, Failure]]
    comptime Arg = Fiber[Token, Failure]
    comptime Out = IO[List[Token], Failure]

    def call_once(deinit self, var fiber: Fiber[Token, Failure]) -> IO[List[Token], Failure]:
        self.handles.append(fiber^)
        if self.next == 6:
            return IO[List[Token], Failure].pure(List[Token]()).flat_map(JoinAll(self.handles^))
        return child(self.next, self.stats).start().flat_map(StartAll(self.next + 1, self.stats.copy(), self.handles^))


@fieldwise_init
struct JoinAll(OnceUnary):
    var handles: List[Fiber[Token, Failure]]
    comptime Arg = List[Token]
    comptime Out = IO[List[Token], Failure]

    def call_once(deinit self, var values: List[Token]) -> IO[List[Token], Failure]:
        if not len(self.handles):
            return IO[List[Token], Failure].pure(values^)
        var fiber = self.handles.pop(0)
        return fiber^.join().flat_map(Collect(values^, self.handles^))


@fieldwise_init
struct Collect(OnceUnary):
    var values: List[Token]
    var handles: List[Fiber[Token, Failure]]
    comptime Arg = Outcome[Token, Failure]
    comptime Out = IO[List[Token], Failure]

    def call_once(deinit self, var outcome: Outcome[Token, Failure]) -> IO[List[Token], Failure]:
        check(Bool(outcome) and outcome.value().is_ok(), "each heterogeneous child succeeds")
        self.values.append(outcome.take()._take_ok())
        return IO[List[Token], Failure].pure(self.values^).flat_map(JoinAll(self.handles^))


def heterogeneous_fibers():
    var stats = new_stats()
    var program = child(0, stats).start().flat_map(StartAll(1, stats.copy(), List[Fiber[Token, Failure]]()))
    var result = run(program^)
    var values = result.take()._take_ok()
    check(len(values) == 6, "every heterogeneous child completes")
    for i in range(6):
        check(values[i].id == i, "values in start order")
    check(stats[][PENDING] == 0 + 2 + 4, "countdown children suspended independently")
    _ = values^
    check(stats[][MACHINES] == 6 and stats[][TOKENS] == 6, "fibers destroy each child and value once")


def erased_pair():
    var stats = new_stats()
    var outcome = run(both(Erased(Countdown(7, 2, String("countdown"), stats.copy())), Erased(Immediate(8, stats.copy()))))
    var pair = outcome.take()._take_ok()
    check(pair[0].id == 7 and pair[1].id == 8, "erased leaves inside a typed pair")
    _ = pair^
    check(stats[][MACHINES] == 2 and stats[][TOKENS] == 2, "pair destroys erased leaves once")


def canceled_after_entry():
    var stats = new_stats()
    var token = CancellationToken()
    var task = Task(Erased(Countdown(9, 100, String("countdown"), stats.copy())), token)
    check(task.tick() and not task.done(), "entered erased machine suspends")
    task.cancel()
    while not task.done():
        _ = task.tick()
    var outcome = task^.finish()
    check(not outcome, "cancellation settles through the carrier")
    check(stats[][MACHINES] == 1 and stats[][TOKENS] == 0, "canceled machine destroyed once")


def borrowed_erased[o: ImmOrigin](ref[o] owner: List[Int]) -> Outcome[Span[Int, o], Span[Int, o]]:
    # The result and error types keep the owner's origin in the carrier type.
    var program = ErasedMachine[Span[Int, o], Span[Int, o]](Borrowed(Pointer(to=owner), 0, False))
    return run(program^)


def origin_in_value():
    var owner = List[Int]([3, 5, 8])
    var outcome = borrowed_erased(owner)
    var view = outcome.take()._take_ok()
    check(len(view) == 3 and view[2] == 8, "borrowed result origin retained by the carrier")


def main():
    separate_runs()
    unopened_and_moved()
    heterogeneous_fibers()
    erased_pair()
    canceled_after_entry()
    origin_in_value()
    print("erased storage: heterogeneous machines, move-only values and errors, exact destruction, retained result origins")
