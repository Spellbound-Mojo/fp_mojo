"""Blocking: laws on Async and on SyncIO (inline), and forwarding through layers."""
from std.atomic import Atomic
from std.ffi import external_call
from std.memory import ArcPointer
from std.os import abort
from fp.algebra import StringMonoid
from fp.callables import OnceThunk, OnceUnary, BorrowCallable
from fp.effects import (Outcome, SyncIO, OptionalT, StateT, WriterT, LiftBlocking,
    Interruption, run_io, run as run_layer, blocking, interruptible, uncancelable, canceled)
from fp.algebra import flat_map
from fp.effects import IO as SyncFamily
from fp.effects.async_runtime import IO, Async, Duration, run

comptime A = Async[Int]
comptime S = SyncIO[Int]


def check(condition: Bool, message: String):
    if not condition:
        abort(String("capability blocking: ", message))


def thread_id() -> UInt64:
    return external_call["pthread_self", UInt64]()


def value_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> T:
    if not outcome or not outcome.value().is_ok():
        abort("capability blocking: expected a success")
    return outcome.take()._take_ok()


def error_of[T: Movable & Deinitable](var outcome: Outcome[T, Int]) -> Int:
    if not outcome or outcome.value().is_ok():
        abort("capability blocking: expected a failure")
    return outcome.take()._take_err().errors.first()


@fieldwise_init
struct Here(OnceThunk):
    """Report whether the function ran on the calling thread."""
    var caller: UInt64
    comptime Out = Bool
    comptime Error = Never

    def call_once(deinit self) -> Bool:
        return thread_id() == self.caller


@fieldwise_init
struct Fails(OnceThunk):
    var error: Int
    comptime Out = Int
    comptime Error = Int

    def call_once(deinit self) raises Int -> Int:
        raise self.error


def six() -> Int:
    return 6


def refuse() raises Int -> Int:
    raise 4


def requested(handle: Interruption) -> Bool:
    return handle.requested()


@fieldwise_init
struct Seen(BorrowCallable):
    var offset: Int
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Never

    def invoke(self, ref handle: Interruption) -> Int:
        return self.offset + (1 if handle.requested() else 0)


@fieldwise_init
struct Record(BorrowCallable):
    var seen: ArcPointer[Atomic[Int]]
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Never

    def invoke(self, ref handle: Interruption) -> Int:
        self.seen[].store(1 if handle.requested() else 2)
        return 0


@fieldwise_init
struct ThenRecord(OnceUnary):
    var seen: ArcPointer[Atomic[Int]]
    comptime Arg = NoneType
    comptime Out = S.Interrupted[Record]

    def call_once(deinit self, var unit: NoneType) -> Self.Out:
        return interruptible[S](Record(self.seen^))


def one_ms() -> Duration:
    var duration = Duration()
    duration._nanoseconds = 1_000_000
    return duration^


def naps(handle: Interruption) -> Int:
    return 1 if handle.sleep(one_ms()) else 2


@fieldwise_init
struct NapRecord(BorrowCallable):
    """Record what an inline sleep and descriptor wait report."""
    var seen: ArcPointer[Atomic[Int]]
    comptime Payload = Interruption
    comptime Result = Int
    comptime Failure = Never

    def invoke(self, ref handle: Interruption) -> Int:
        var slept = handle.sleep(Duration())
        var ready = True
        try:
            ready = handle.await_readable(RawFileDescriptor(0), Optional(Duration()))
        except:
            pass
        self.seen[].store((10 if slept else 20) + (1 if ready else 2))
        return 0


@fieldwise_init
struct ThenNap(OnceUnary):
    var seen: ArcPointer[Atomic[Int]]
    comptime Arg = NoneType
    comptime Out = S.Interrupted[NapRecord]

    def call_once(deinit self, var unit: NoneType) -> Self.Out:
        return interruptible[S](NapRecord(self.seen^))


def async_laws():
    # blocking(f) produces what delay(f) produces, on another thread.
    check(value_of(run(blocking[A](six))) == value_of(run(IO[Int, Int].delay(six))), "blocking(f) has delay(f)'s value")
    check(error_of(run(blocking[A](refuse))) == error_of(run(IO[Int, Int].delay(refuse))), "blocking(f) has delay(f)'s error")
    check(error_of(run(blocking[A](Fails(3)))) == 3, "a library callable's error returns")
    check(not value_of(run(blocking[A](Here(thread_id())))), "Async runs blocking calls off the root's thread")
    # Uncanceled, interruptible(f) sees no request.
    check(value_of(run(interruptible[A](Seen(10)))) == 10, "an uncanceled handle reports no request")
    check(not value_of(run(interruptible[A](requested))), "a plain function borrows the handle")


def sync_laws() raises:
    check(value_of(run_io(blocking[S](six))) == 6, "SyncIO's blocking runs inline")
    check(error_of(run_io(blocking[S](Fails(5)))) == 5, "SyncIO's blocking error returns")
    check(value_of(run_io(blocking[S](Here(thread_id())))), "SyncIO runs blocking calls on the calling thread")
    check(value_of(run_io(interruptible[S](Seen(20)))) == 20, "SyncIO's handle reports no request")
    # Masked, a canceled token reaches the function through its handle.
    var seen = ArcPointer(Atomic[Int](0))
    var masked = run_io(uncancelable(flat_map[SyncFamily[Int]](canceled[S](), ThenRecord(seen.copy()))))
    check(not masked, "the masked program observes cancellation after the region")
    check(seen[].load() == 1, "SyncIO's handle reads the context token")
    # Inline waits: an uninterrupted sleep runs out; a prior request ends waits at once.
    check(value_of(run_io(interruptible[S](naps))) == 1, "SyncIO's inline sleep runs its duration")
    var napped = ArcPointer(Atomic[Int](0))
    _ = run_io(uncancelable(flat_map[SyncFamily[Int]](canceled[S](), ThenNap(napped.copy()))))
    check(napped[].load() == 22, String("SyncIO's waits end at once after a request, saw ", napped[].load()))


comptime O = OptionalT[A]
comptime OB = LiftBlocking[O, A]


def layers():
    check(value_of(run(blocking[OB](six))) == Optional(6), "blocking through OptionalT")
    check(value_of(run(interruptible[OB](Seen(1)))) == Optional(1), "interruptible through OptionalT")
    check(error_of(run(blocking[OB](refuse))) == 4, "a blocking error through OptionalT is the base's failure")

    comptime ST = StateT[A, Int]
    var stateful = value_of(run(run_layer[ST](blocking[LiftBlocking[ST, A]](six), 3)))
    check(stateful[0] == 6 and stateful[1] == 3, "blocking through StateT keeps the state")

    comptime W = WriterT[A, StringMonoid]
    var written = value_of(run(run_layer[W](interruptible[LiftBlocking[W, A]](Seen(2)))))
    check(written[0] == "" and written[1] == 2, "interruptible through WriterT logs nothing")

    comptime SO = OptionalT[SyncFamily[Int]]
    check(value_of(run_io(blocking[LiftBlocking[SO, S]](six))) == Optional(6), "blocking through OptionalT over SyncIO")


def main() raises:
    async_laws()
    sync_laws()
    layers()
    print("capability blocking: delay laws on Async off-thread and on SyncIO inline, handles and inline waits, layer forwarding")
