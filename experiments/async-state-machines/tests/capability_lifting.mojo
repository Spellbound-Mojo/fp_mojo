"""Defer, Raise, Cancel and Spawn lifted through transformer layers over Async."""
from std.memory import ArcPointer
from std.os import abort
from fp.algebra import Monad, flat_map, map, StringMonoid
from fp.algebra.protocols import _Lifting
from fp.callables import OnceThunk, OnceUnary
from fp.data import Result
from fp.effects import (Outcome, Defer, Cancel, OptionalT, ResultT, ReaderT, StateT, WriterT, LiftDefer, LiftRaise, LiftCancel, LiftSpawn,
    delay, defer, raise_error, guarantee, on_cancel, uncancelable, canceled, start, join, cancel, never, cede, lift, run as run_layer)
from fp.effects.async_runtime import IO, Async, Fiber, run

comptime A = Async[Int]
comptime O = OptionalT[A]
comptime OD = LiftDefer[O, A]
comptime OS = LiftSpawn[O, A]
comptime R = ResultT[A, String]
comptime RD = LiftDefer[R, A]
comptime RS = LiftSpawn[R, A]


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def summary[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    """The success; a failure or cancellation aborts."""
    if not outcome or not outcome.value().is_ok():
        abort("expected a success")
    return outcome.take()._take_ok()


def failure[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> Int:
    """-2 for cancellation, -1000 - error for a failure, 0 for a success."""
    if not outcome:
        return -2
    var result = outcome.take()
    if result.is_ok():
        return 0
    return -1000 - result^._take_err().errors.first()


@fieldwise_init
struct Count(OnceThunk):
    var calls: ArcPointer[Int]
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        self.calls[] += 1
        return self.calls[] * 10


@fieldwise_init
struct Mark(OnceThunk):
    var marks: ArcPointer[Int]
    comptime Out = NoneType
    comptime Error = Never

    def call_once(deinit self) -> NoneType:
        self.marks[] += 1
        return None


@fieldwise_init
struct Build(OnceThunk):
    """Build an absent OptionalT program only when reached."""
    var built: ArcPointer[Int]
    comptime Out = IO[Optional[Int], Int]
    comptime Error = Never

    def call_once(deinit self) -> IO[Optional[Int], Int]:
        self.built[] += 1
        return IO[Optional[Int], Int].pure(Optional[Int]())


@fieldwise_init
struct BuildLayer[I: Monad & _Lifting](OnceThunk):
    """Build a lifted program of a layer only when reached."""
    var built: ArcPointer[Int]
    comptime Out = Self.I.Lifted[IO[Int, Int]]
    comptime Error = Self.I.LiftError[IO[Int, Int]]

    def call_once(deinit self) raises Self.Error -> Self.Out:
        self.built[] += 1
        return lift[Self.I](IO[Int, Int].pure(5))


def guarded[D: Defer, K: Cancel](calls: ArcPointer[Int], marks: ArcPointer[Int]) -> K.Guaranteed[D.Delayed[Count], D.Delayed[Mark]] where D.DelayCompatible[Count] and D.DelayCompatible[Mark] and K.GuaranteeCompatible[D.Delayed[Count], D.Delayed[Mark]]:
    """One generic program, given separate Defer and Cancel selections."""
    return guarantee[K](delay[D](Count(calls.copy())), delay[D](Mark(marks.copy())))


def layers_defer_and_raise() raises:
    var calls = ArcPointer(0)
    var built = ArcPointer(0)
    check(summary(run(delay[OD](Count(calls.copy())))) == Optional(10), "delay through OptionalT")
    var deferred = defer[OD](Build(built.copy()))
    check(built[] == 0, "defer through OptionalT builds nothing at construction")
    check(not summary(run(deferred^)), "defer through OptionalT builds and runs the absent program when reached")
    check(built[] == 1, "the factory ran once")
    check(failure(run(raise_error[LiftRaise[O, A], Int](Int(4)))) == -1004, "raise_error through OptionalT raises the base error")
    check(failure(run(raise_error[LiftRaise[R, A], Int](Int(5)))) == -1005, "raise_error through ResultT raises the base error, not the stored one")

    comptime RT = ReaderT[A, Int]
    var reader = delay[LiftDefer[RT, A]](Count(calls.copy()))
    var env = 3
    check(summary(run(run_layer[RT](reader^, env))) == 20, "delay through ReaderT runs when the IO reaches it")
    check(failure(run(run_layer[RT](raise_error[LiftRaise[RT, A], Int](Int(6)), env))) == -1006, "raise_error through ReaderT")

    comptime ST = StateT[A, Int]
    var state = delay[LiftDefer[ST, A]](Count(calls.copy()))
    var paired = summary(run(run_layer[ST](state^, 9)))
    check(paired[0] == 30 and paired[1] == 9, "delay through StateT keeps the state")
    check(failure(run(run_layer[ST](raise_error[LiftRaise[ST, A], Int](Int(7)), 9))) == -1007, "raise_error through StateT")
    built[] = 0
    var stateful = run_layer[ST](defer[LiftDefer[ST, A]](BuildLayer[ST](built.copy())), 9)
    check(built[] == 0, "defer through StateT builds nothing when the state runs")
    var running = run(stateful^)
    check(built[] == 1, "defer through StateT builds when the IO reaches it")
    var built_pair = summary(running^)
    check(built_pair[0] == 5 and built_pair[1] == 9, "defer through StateT runs the built program with the state")

    comptime WT = WriterT[A, StringMonoid]
    var logged = summary(run(run_layer[WT](delay[LiftDefer[WT, A]](Count(calls.copy())))))
    check(logged[0] == "" and logged[1] == 40, "delay through WriterT logs nothing")
    check(failure(run(run_layer[WT](raise_error[LiftRaise[WT, A], Int](Int(8))))) == -1008, "raise_error through WriterT")
    var written = run_layer[WT](defer[LiftDefer[WT, A]](BuildLayer[WT](built.copy())))
    check(built[] == 1, "defer through WriterT builds nothing at construction")
    var built_log = summary(run(written^))
    check(built[] == 2 and built_log[1] == 5, "defer through WriterT builds and runs when reached")


def layers_cancel() raises:
    var calls = ArcPointer(0)
    var marks = ArcPointer(0)
    check(summary(run(guarded[A, A](calls, marks))) == 10 and marks[] == 1, "the generic program on Async")
    check(summary(run(guarded[OD, LiftCancel[O, A]](calls, marks))) == Optional(20) and marks[] == 2, "the same program through OptionalT")

    marks[] = 0
    var absent = guarantee[OS](IO[Optional[Int], Int].pure(Optional[Int]()), delay[OD](Mark(marks.copy())))
    check(not summary(run(absent^)) and marks[] == 1, "an absent OptionalT program still runs its finalizer")
    var stored = guarantee[RS](R.fail[Int](String("bad")), delay[RD](Mark(marks.copy())))
    var result = summary(run(stored^))
    check(result.is_err() and marks[] == 2, "a ResultT program's stored error still runs its finalizer")

    marks[] = 0
    var only = on_cancel[OS](IO[Optional[Int], Int].pure(Optional(1)), delay[OD](Mark(marks.copy())))
    check(summary(run(only^)) == Optional(1) and marks[] == 0, "on_cancel skips its finalizer without cancellation")
    var stopped = on_cancel[OS](canceled[OS](), delay[OD](Mark(marks.copy())))
    check(failure(run(stopped^)) == -2 and marks[] == 1, "a lifted cancellation runs on_cancel finalizers")

    calls[] = 0
    check(summary(run(uncancelable[OS](Region(calls.copy())))) == Optional(10), "a masked OptionalT region")


@fieldwise_init
struct Region(OnceUnary):
    var calls: ArcPointer[Int]
    comptime Arg = OS.RegionPoll
    comptime Out = OD.Delayed[Count]

    def call_once(deinit self, var poll: OS.RegionPoll) -> OD.Delayed[Count]:
        return delay[OD](Count(self.calls^))


@fieldwise_init
struct JoinOptional(OnceUnary):
    comptime Arg = OS.Handle[Int]
    comptime Out = OS.Joined[Int]

    def call_once(deinit self, var fiber: OS.Handle[Int]) -> OS.Joined[Int]:
        return join[OS, Int](fiber^)


@fieldwise_init
struct JoinResult(OnceUnary):
    comptime Arg = RS.Handle[Int]
    comptime Out = RS.Joined[Int]

    def call_once(deinit self, var fiber: RS.Handle[Int]) -> RS.Joined[Int]:
        return join[RS, Int](fiber^)


@fieldwise_init
struct CancelThenJoin(OnceUnary):
    comptime Arg = OS.Handle[Int]
    comptime Out = IO[Optional[Outcome[Optional[Int], Int]], Int]

    def call_once(deinit self, var fiber: OS.Handle[Int]) -> Self.Out:
        var stopping = cancel[OS, Int](fiber)
        return flat_map[O](stopping^, JoinAfter(fiber^))


@fieldwise_init
struct JoinAfter(OnceUnary):
    var fiber: OS.Handle[Int]
    comptime Arg = NoneType
    comptime Out = OS.Joined[Int]

    def call_once(deinit self, var unit: NoneType) -> OS.Joined[Int]:
        return join[OS, Int](self.fiber^)


@fieldwise_init
struct Five(OnceUnary):
    comptime Arg = NoneType
    comptime Out = Int

    def call_once(deinit self, var unit: NoneType) -> Int:
        return 5


def joined[T: Movable & Deinitable](var outcome: Outcome[Optional[Outcome[T, Int]], Int]) -> Outcome[T, Int]:
    var lifted = summary(outcome^)
    check(Bool(lifted), "a lifted join through OptionalT is present")
    return lifted.take()


def joined_result[T: Movable & Deinitable](var outcome: Outcome[Result[Outcome[T, Int], String], Int]) -> Outcome[T, Int]:
    var lifted = summary(outcome^)
    check(lifted.is_ok(), "a lifted join through ResultT is Ok")
    return lifted^._take_ok()


def layers_spawn() raises:
    var present = flat_map[O](start[OS](IO[Optional[Int], Int].pure(Optional(5))), JoinOptional())
    check(summary(joined(run(present^))) == Optional(5), "start then join through OptionalT")
    var absent = flat_map[O](start[OS](IO[Optional[Int], Int].pure(Optional[Int]())), JoinOptional())
    check(not summary(joined(run(absent^))), "an absent fiber joins as a success holding absence")
    var stored: IO[Result[Outcome[Result[Int, String], Int], String], Int] = flat_map[R](start[RS](R.fail[Int](String("bad"))), JoinResult())
    check(summary(joined_result[Result[Int, String]](run(stored^))).is_err(), "a ResultT fiber's stored error is a successful outcome")
    var forever = flat_map[O](start[OS](never[OS, Int]()), CancelThenJoin())
    check(failure(joined(run(forever^))) == -2, "cancel then join through OptionalT produces cancellation")
    var ceded = map[O](cede[OS](), Five())
    check(summary(run(ceded^)) == Optional(5), "cede through OptionalT")


def main() raises:
    layers_defer_and_raise()
    layers_cancel()
    layers_spawn()
    print("capability lifting: Defer and Raise through OptionalT, ResultT, ReaderT, StateT and WriterT; Cancel and Spawn through OptionalT and ResultT")
