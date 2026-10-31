"""The one implementation of each derived time operation, over any clock source.

timed reads a clock, runs the program, reads the clock again, and pairs the
elapsed Duration with the value. delay_by sleeps, then runs the program;
and_wait runs it, then sleeps, keeping its value. Each binds through the
source's family, as Cats Effect derives them, so a failure or a layer's own
absence skips the steps after it: it has no duration and no sleep after it.

Dictionaries name a private source rather than themselves: a Timing member
defined through the dictionary's own Timing conformance is a recursive
declaration in Mojo 1.2.
"""
from fp.algebra.protocols import Monad, _Lifting, _map_as, _flat_map_as
from fp.algebra._primitive_contracts import MapContract, BindContract
from fp.callables.protocols import OnceUnary
from fp.callables._transforms import _Fill
from fp._internal.errors import _ErrorCompatible
from fp._internal.time import Duration, Instant
from .protocols import Timing, Temporal
from ._adapt import _lift_as


trait _ClockSource:
    """A family and the carrier reading its clock."""
    comptime Family: Monad
    comptime Reading: Movable & Deinitable

    @staticmethod
    def read() -> Self.Reading:
        ...


trait _SleepSource(_ClockSource):
    """A clock source that can also sleep on its clock."""
    comptime Slept: Movable & Deinitable

    @staticmethod
    def sleep(duration: Duration) -> Self.Slept:
        ...


struct _LiftedClock[I: Monad & _Lifting, C: Timing](_ClockSource, not Deinitable):
    """The base's clock reading, lifted through one layer."""
    comptime Family = Self.I
    comptime Reading = Self.I.Lifted[Self.C.Monotonic]

    @staticmethod
    def read() -> Self.Reading:
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Monotonic]], "monotonic: lifting into the layer must not fail"
        return _lift_as[Never, Self.I](Self.C.monotonic())


struct _LiftedSleep[I: Monad & _Lifting, C: Temporal](_SleepSource, not Deinitable):
    """The base's clock reading and sleep, lifted through one layer."""
    comptime Family = Self.I
    comptime Reading = _LiftedClock[Self.I, Self.C].Reading
    comptime Slept = Self.I.Lifted[Self.C.Slept]

    @staticmethod
    def read() -> Self.Reading:
        return _LiftedClock[Self.I, Self.C].read()

    @staticmethod
    def sleep(duration: Duration) -> Self.Slept:
        comptime assert _ErrorCompatible[Never, Self.I.LiftError[Self.C.Slept]], "sleep: lifting into the layer must not fail"
        return _lift_as[Never, Self.I](Self.C.sleep(duration))


@fieldwise_init
struct _TimedEnd[A: Movable & Deinitable](OnceUnary):
    """Pair the elapsed duration with the value."""
    var start: Instant
    var value: Self.A
    comptime Arg = Instant
    comptime Out = Tuple[Duration, Self.A]

    def call_once(deinit self, var end: Instant) -> Tuple[Duration, Self.A]:
        return (end.since(self.start), self.value^)


@fieldwise_init
struct _TimedValue[R: _ClockSource, A: Movable & Deinitable](OnceUnary):
    """Read the clock again after the program's value."""
    var start: Instant
    comptime Arg = Self.A
    comptime _Map = MapContract[Self.R.Family, Self.R.Reading, _TimedEnd[Self.A]]
    comptime Out = Self._Map.Out
    comptime Error = Self._Map.Error

    def call_once(deinit self, var value: Self.A) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.R.Family.MapError[Self.R.Reading, _TimedEnd[Self.A]]]
        return _map_as[Self.Error, Self.R.Family](_TimedEnd[Self.A](self.start^, value^), Self.R.read())


@fieldwise_init
struct _TimedStart[R: _ClockSource, V: Movable & Deinitable](OnceUnary):
    """Run the program after the first reading."""
    var program: Self.V
    comptime Arg = Instant
    comptime A = Self.R.Family.Element[Self.V]
    comptime _Bind = BindContract[Self.R.Family, Self.V, _TimedValue[Self.R, Self.A]]
    comptime Out = Self._Bind.Out
    comptime Error = Self._Bind.Error

    def call_once(deinit self, var start: Instant) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.R.Family.BindError[Self.V, _TimedValue[Self.R, Self.A]]]
        return _flat_map_as[Self.Error, Self.R.Family](_TimedValue[Self.R, Self.A](start^), self.program^)


comptime _TimedBind[R: _ClockSource, V: Movable & Deinitable] = BindContract[R.Family, R.Reading, _TimedStart[R, V]]
comptime _TimedOf[R: _ClockSource, V: Movable & Deinitable] = _TimedBind[R, V].Out
comptime _TimesCompatible[R: _ClockSource, V: Movable & Deinitable] = (
    R.Family.CarrierCompatible[V] and _TimedBind[R, V].Compatible
    and _ErrorCompatible[Never, _TimedBind[R, V].Error])


def _timed[R: _ClockSource, V: Movable & Deinitable](var program: V) -> _TimedOf[R, V]:
    """Measure a program on R's clock; the family admits each step."""
    comptime assert _ErrorCompatible[Never, R.Family.BindError[R.Reading, _TimedStart[R, V]]], "timed: building the measurement must not fail"
    return _flat_map_as[Never, R.Family](_TimedStart[R, V](program^), R.read())


comptime _DelayBind[S: _SleepSource, V: Movable & Deinitable] = BindContract[S.Family, S.Slept, _Fill[NoneType, V]]
comptime _DelayedOf[S: _SleepSource, V: Movable & Deinitable] = _DelayBind[S, V].Out
comptime _DelaysCompatible[S: _SleepSource, V: Movable & Deinitable] = (
    S.Family.CarrierCompatible[V] and _DelayBind[S, V].Compatible
    and _ErrorCompatible[Never, _DelayBind[S, V].Error])


def _delay_by[S: _SleepSource, V: Movable & Deinitable](var program: V, duration: Duration) -> _DelayedOf[S, V]:
    """Sleep on S's clock, then run the program."""
    comptime assert _ErrorCompatible[Never, S.Family.BindError[S.Slept, _Fill[NoneType, V]]], "delay_by: building the sleep must not fail"
    return _flat_map_as[Never, S.Family](_Fill[NoneType, V](program^), S.sleep(duration))


@fieldwise_init
struct _WaitThen[S: _SleepSource, A: Movable & Deinitable](OnceUnary):
    """Sleep after the value, then produce it."""
    var duration: Duration
    comptime Arg = Self.A
    comptime _Map = MapContract[Self.S.Family, Self.S.Slept, _Fill[NoneType, Self.A]]
    comptime Out = Self._Map.Out
    comptime Error = Self._Map.Error

    def call_once(deinit self, var value: Self.A) raises Self.Error -> Self.Out:
        comptime assert _ErrorCompatible[Self.Error, Self.S.Family.MapError[Self.S.Slept, _Fill[NoneType, Self.A]]]
        return _map_as[Self.Error, Self.S.Family](_Fill[NoneType, Self.A](value^), Self.S.sleep(self.duration))


comptime _WaitBind[S: _SleepSource, V: Movable & Deinitable] = BindContract[S.Family, V, _WaitThen[S, S.Family.Element[V]]]
comptime _WaitedOf[S: _SleepSource, V: Movable & Deinitable] = _WaitBind[S, V].Out
comptime _WaitsCompatible[S: _SleepSource, V: Movable & Deinitable] = (
    S.Family.CarrierCompatible[V] and _WaitBind[S, V].Compatible
    and _ErrorCompatible[Never, _WaitBind[S, V].Error])


def _and_wait[S: _SleepSource, V: Movable & Deinitable](var program: V, duration: Duration) -> _WaitedOf[S, V]:
    """Run the program, then sleep on S's clock, keeping its value."""
    comptime A = S.Family.Element[V]
    comptime assert _ErrorCompatible[Never, S.Family.BindError[V, _WaitThen[S, A]]], "and_wait: building the sleep must not fail"
    return _flat_map_as[Never, S.Family](_WaitThen[S, A](duration.copy()), program^)
