"""Shared controls for opt-in qualification, never imported by the runtime."""
from std.os import abort
from std.sys import argv
from std.time import perf_counter_ns
from fp.data import Result, Ok
from fp.effects import Outcome, EffectFailure
from fp.effects.async_runtime import Clock, Instant


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def success[T: Movable & Deinitable](var value: T) -> Outcome[T, Int]:
    return Optional(Result[T, EffectFailure[Int]](Ok(value^)))


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
