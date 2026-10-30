"""The private IO engine: sequencing, recovery, leaves, cancellation, exact ownership."""
from std.memory import ArcPointer
from fp.callables import OnceUnary, OnceThunk
from fp.effects import IOContext, CancellationToken, Outcome, EffectFailure
from state_machine import IO, Machine, Step, Wait, Task, run, both
from foundation import check, success, Failure

# Stats slots: 0 callbacks invoked, 1 callbacks dropped unopened, 2 tokens
# destroyed, 3 leaf polls, 4 failures destroyed (foundation.Failure), 5 leaves destroyed.
comptime INVOKED = 0
comptime DROPPED = 1
comptime TOKENS = 2
comptime POLLS = 3
comptime FAILURES = 4
comptime LEAVES = 5


def new_stats() -> ArcPointer[List[Int]]:
    return ArcPointer(List[Int]([0, 0, 0, 0, 0, 0]))


@fieldwise_init
struct Token(Movable):
    var id: Int
    var stats: ArcPointer[List[Int]]

    def __deinit__(deinit self):
        self.stats[][TOKENS] += 1


@fieldwise_init
struct Next(OnceUnary):
    """Consume a token and continue with a fresh one; dropped unopened is counted."""
    var stats: ArcPointer[List[Int]]
    comptime Arg = Token
    comptime Out = IO[Token, Failure]

    def __deinit__(deinit self):
        self.stats[][DROPPED] += 1

    def call_once(deinit self, var token: Token) -> IO[Token, Failure]:
        self.stats[][INVOKED] += 1
        return IO[Token, Failure].pure(Token(token.id + 1, self.stats.copy()))


@fieldwise_init
struct Double(OnceUnary):
    var stats: ArcPointer[List[Int]]
    comptime Arg = Token
    comptime Out = Token

    def __deinit__(deinit self):
        self.stats[][DROPPED] += 1

    def call_once(deinit self, var token: Token) -> Token:
        self.stats[][INVOKED] += 1
        return Token(token.id * 2, self.stats.copy())


@fieldwise_init
struct Raise(OnceUnary):
    var code: Int
    var stats: ArcPointer[List[Int]]
    comptime Arg = Token
    comptime Out = IO[Token, Failure]
    comptime Error = Failure

    def __deinit__(deinit self):
        self.stats[][DROPPED] += 1

    def call_once(deinit self, var token: Token) raises Failure -> IO[Token, Failure]:
        self.stats[][INVOKED] += 1
        raise Failure(self.code, self.stats.copy())


@fieldwise_init
struct Recover(OnceUnary):
    var stats: ArcPointer[List[Int]]
    comptime Arg = EffectFailure[Failure]
    comptime Out = IO[Token, Failure]

    def __deinit__(deinit self):
        self.stats[][DROPPED] += 1

    def call_once(deinit self, var failure: EffectFailure[Failure]) -> IO[Token, Failure]:
        self.stats[][INVOKED] += 1
        var errors = failure^.into_errors().into_list()
        return IO[Token, Failure].pure(Token(errors[0].code + 100, self.stats.copy()))


@fieldwise_init
struct Build(OnceThunk):
    var id: Int
    var stats: ArcPointer[List[Int]]
    comptime Out = IO[Token, Failure]
    comptime Error = Never

    def __deinit__(deinit self):
        self.stats[][DROPPED] += 1

    def call_once(deinit self) -> IO[Token, Failure]:
        self.stats[][INVOKED] += 1
        return IO[Token, Failure].pure(Token(self.id, self.stats.copy()))


@fieldwise_init
struct Countdown(Machine):
    var id: Int
    var remaining: Int
    var stats: ArcPointer[List[Int]]
    comptime Value = Token
    comptime Error = Failure

    def __deinit__(deinit self):
        self.stats[][LEAVES] += 1

    def poll(mut self, context: IOContext[Failure]) -> Step[Token, Failure]:
        self.stats[][POLLS] += 1
        if context.canceled():
            return .ready(None)
        if self.remaining > 0:
            self.remaining -= 1
            return .pending(Wait())
        return success[Token, Failure](Token(self.id, self.stats.copy()))


def token(id: Int, stats: ArcPointer[List[Int]]) -> IO[Token, Failure]:
    return IO[Token, Failure].pure(Token(id, stats.copy()))


def take_id(var outcome: Outcome[Token, Failure]) -> Int:
    return outcome.take()._take_ok().id


def take_code(var outcome: Outcome[Token, Failure]) -> Int:
    var errors = outcome.take()._take_err().into_errors().into_list()
    return errors[0].code


def sequencing():
    var stats = new_stats()
    var io = token(1, stats).flat_map(Next(stats.copy())).flat_map(Next(stats.copy())).map(Double(stats.copy()))
    check(stats[][INVOKED] == 0 and stats[][TOKENS] == 0, "construction invokes nothing")
    check(take_id(run(io^)) == 6, "binds and map run in order")
    check(stats[][INVOKED] == 3 and stats[][DROPPED] == 0, "each callback invoked once")
    check(stats[][TOKENS] == 4, "each intermediate token destroyed once")


def failure_skips_continuations():
    var stats = new_stats()
    var io = token(1, stats).flat_map(Raise(7, stats.copy())).flat_map(Next(stats.copy())).map(Double(stats.copy()))
    check(take_code(run(io^)) == 7, "callback failure captured with its exact error")
    check(stats[][INVOKED] == 1 and stats[][DROPPED] == 2, "later continuations dropped unopened")
    check(stats[][TOKENS] == 1 and stats[][FAILURES] == 1, "payloads destroyed once")


def recovery():
    var stats = new_stats()
    var failed = IO[Token, Failure].raise_error(Failure(5, stats.copy())).handle_error_with(Recover(stats.copy()))
    check(take_id(run(failed^)) == 105, "handler replaces an ordinary failure")
    check(stats[][INVOKED] == 1 and stats[][FAILURES] == 1, "handler consumed the failure")
    var ok = token(9, stats).handle_error_with(Recover(stats.copy())).flat_map(Next(stats.copy()))
    check(take_id(run(ok^)) == 10, "success skips recovery")
    check(stats[][INVOKED] == 2 and stats[][DROPPED] == 1, "skipped handler dropped unopened")


def deferred_construction():
    var stats = new_stats()
    var io = IO[Token, Failure].defer(Build(3, stats.copy())).flat_map(Next(stats.copy()))
    check(stats[][INVOKED] == 0, "defer does not build at construction")
    check(take_id(run(io^)) == 4, "deferred program runs")
    check(stats[][INVOKED] == 2 and stats[][DROPPED] == 0, "factory invoked once")
    var unopened = IO[Token, Failure].defer(Build(3, stats.copy()))
    _ = unopened^
    check(stats[][INVOKED] == 2 and stats[][DROPPED] == 1, "unopened factory dropped without invocation")


def leaves():
    var stats = new_stats()
    var io = IO[Token, Failure].lift(Countdown(4, 3, stats.copy())).flat_map(Next(stats.copy()))
    check(take_id(run(io^)) == 5, "a suspended leaf resumes the chain")
    check(stats[][POLLS] == 4 and stats[][LEAVES] == 1, "leaf polled until terminal and destroyed once")
    var pair = run(both(token(1, stats).flat_map(Next(stats.copy())), IO[Token, Failure].lift(Countdown(7, 2, stats.copy()))))
    var values = pair.take()._take_ok()
    check(values[0].id == 2 and values[1].id == 7, "IO values run inside a typed pair")


def canceled_at_handoff():
    var stats = new_stats()
    var io = IO[Token, Failure].lift(Countdown(1, 100, stats.copy())).flat_map(Next(stats.copy()))
    var token = CancellationToken()
    var task = Task(io^, token)
    for _ in range(3):
        _ = task.tick()
    check(not task.done(), "leaf still running before cancellation")
    task.cancel()
    while not task.done():
        _ = task.tick()
    var outcome = task^.finish()
    check(not outcome, "cancellation settles through the engine")
    check(stats[][INVOKED] == 0 and stats[][DROPPED] == 1, "pending continuation dropped unopened")
    check(stats[][LEAVES] == 1 and stats[][TOKENS] == 0, "canceled leaf destroyed once")


def unopened_disposal():
    var stats = new_stats()
    var io = IO[Token, Failure].lift(Countdown(1, 1, stats.copy())).flat_map(Next(stats.copy())).handle_error_with(Recover(stats.copy()))
    _ = io^
    check(stats[][DROPPED] == 2 and stats[][LEAVES] == 1 and stats[][POLLS] == 0, "unopened tree destroyed without running")


def main():
    sequencing()
    failure_skips_continuations()
    recovery()
    deferred_construction()
    leaves()
    canceled_at_handoff()
    unopened_disposal()
    print("io engine: sequencing, recovery, deferred construction, leaves, cancellation, exact ownership")
