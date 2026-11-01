"""A minimal test family providing only Defer and Raise, to check narrower providers."""
from std.memory import ArcPointer
from std.os import abort
from fp.callables import OnceThunk
from fp.callables.protocols import ThunkContract
from fp.effects import IO as SyncIOFamily, Outcome, Defer, Raise, SyncIO, run_io, delay, defer, raise_error


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


struct DeferOnly[E: Movable & Deinitable](Defer, Raise, not Deinitable):
    """Defer and Raise over the synchronous family; no Cancel and no Spawn."""
    comptime Family = SyncIOFamily[Self.E]
    comptime Error = Self.E
    comptime DelayCompatible[F: ThunkContract & Movable & Deinitable] = SyncIO[Self.E].DelayCompatible[F]
    comptime Delayed[F: ThunkContract & Movable & Deinitable] = SyncIO[Self.E].Delayed[F]
    comptime DeferCompatible[F: ThunkContract & Movable & Deinitable] = SyncIO[Self.E].DeferCompatible[F]
    comptime Deferred[F: ThunkContract & Movable & Deinitable] = SyncIO[Self.E].Deferred[F]
    comptime Raised[A: Movable & Deinitable] = SyncIO[Self.E].Raised[A]

    @staticmethod
    def delay[F: ThunkContract & Movable & Deinitable](var function: F) -> Self.Delayed[F]:
        return SyncIO[Self.E].delay(function^)

    @staticmethod
    def defer[F: ThunkContract & Movable & Deinitable](var factory: F) -> Self.Deferred[F]:
        return SyncIO[Self.E].defer(factory^)

    @staticmethod
    def raise_error[A: Movable & Deinitable](var error: Self.E) -> Self.Raised[A]:
        return SyncIO[Self.E].raise_error[A](error^)


@fieldwise_init
struct Count(OnceThunk):
    var calls: ArcPointer[Int]
    comptime Out = Int
    comptime Error = Never

    def call_once(deinit self) -> Int:
        self.calls[] += 1
        return 3


def counted[I: Defer](calls: ArcPointer[Int]) -> I.Delayed[Count] where I.DelayCompatible[Count]:
    return delay[I](Count(calls.copy()))


def main():
    var calls = ArcPointer(0)
    var outcome = run_io(counted[DeferOnly[Int]](calls))
    check(Bool(outcome) and outcome.value().is_ok() and outcome.take()._take_ok() == 3 and calls[] == 1, "a Defer-only client runs on the test family")
    var failed = run_io(raise_error[DeferOnly[Int], Int](Int(2)))
    check(Bool(failed) and failed.value().is_err(), "a Raise client runs on the test family")
    print("capability family: Defer and Raise clients run on a narrower provider")
