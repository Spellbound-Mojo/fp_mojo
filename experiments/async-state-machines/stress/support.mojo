"""Shared controls for opt-in qualification, never imported by the runtime."""
from std.os import abort
from std.sys import argv
from std.time import perf_counter_ns
from fp.data import Result, Ok
from fp.effects import Outcome, EffectFailure
from fp.effects.async_runtime import Clock, Instant
from fp._internal.cells import _lock_metadata
from fp._internal.waking import _Runtime


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def success[T: Movable & Deinitable](var value: T) -> Outcome[T, Int]:
    return Optional(Result[T, EffectFailure[Int]](Ok(value^)))


def timer_entries(runtime: _Runtime) -> Int:
    """Entries in the root's timer heap, armed or canceled.

    The heap belongs to the root's scheduler, not to a registry. Call this
    before taking a registry lock: the heap's lock may be held while a
    registry's is taken, never the reverse.
    """
    var scheduler = runtime.scheduler()
    var guard = _lock_metadata(scheduler[].timers)
    var entries = len(guard.cell[].slot.value().heap)
    _ = guard^
    return entries


def root_live_timers(runtime: _Runtime) -> Int:
    """Deadlines armed across the root's registries, which bound the heap's tombstones."""
    return runtime.scheduler()[].live_timers().load()


def advance(clock: Clock, deadline: Instant):
    try:
        clock.advance_to(deadline)
    except:
        abort("qualification attempted invalid manual time advance")


struct Window(Copyable):
    var start: Int
    var nanoseconds: Int
    var minimum: Int

    def __init__(out self) raises:
        var args = argv()
        check(len(args) == 1 or len(args) == 3, "expected seconds and minimum cycles")
        var seconds = Int(args[1]) if len(args) == 3 else 0
        self.minimum = Int(args[2]) if len(args) == 3 else 64
        check(0 <= seconds <= 86400 and 1 <= self.minimum <= 1000000000, "bounded qualification arguments")
        self.start = Int(perf_counter_ns())
        self.nanoseconds = seconds * 1000000000

    def elapsed(self) -> Int:
        return Int(perf_counter_ns()) - self.start

    def more(self, cycles: Int) -> Bool:
        return cycles < self.minimum or self.elapsed() < self.nanoseconds
