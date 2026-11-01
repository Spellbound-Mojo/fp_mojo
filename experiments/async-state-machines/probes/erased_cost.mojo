"""Diagnostic timings: erased dispatch, storage and IO steps against the typed path."""
from std.memory import OwnedPointer, ArcPointer
from std.time import perf_counter_ns
from std.os import abort
from fp.callables import Unary, OnceUnary
from fp.data import ControlFlow, Continue, Break
from fp.effects import IOContext, CancellationToken
from fp.effects._async.kernel import Machine, Step, Wait, run
from fp.effects._async.composition import Pure, pure, loop
from fp.effects._async.erased import _ErasedMachine
from fp.effects._async.engine import IO


def check(condition: Bool, message: String):
    if not condition:
        abort(message)


def mix(value: Int) -> Int:
    return (value * 1664525 + 1013904223) & 268435455


comptime State = Tuple[Int, Int]
comptime Flow = ControlFlow[Int, State]


@fieldwise_init
struct TypedStep(Unary):
    var limit: Int
    comptime Arg = State
    comptime Out = Pure[Flow, Int]
    def call(self, var value: State) -> Self.Out:
        if value[0] == self.limit:
            return pure[Int](Flow(Break(value[1])))
        return pure[Int](Flow(Continue((value[0] + 1, mix(value[1])))))


@fieldwise_init
struct ErasedStep(Unary):
    var limit: Int
    comptime Arg = State
    comptime Out = _ErasedMachine[Flow, Int]
    def call(self, var value: State) -> Self.Out:
        if value[0] == self.limit:
            return Self.Out(pure[Int](Flow(Break(value[1]))))
        return Self.Out(pure[Int](Flow(Continue((value[0] + 1, mix(value[1]))))))


@no_inline
def loop_typed(count: Int, seed: Int) -> Int:
    var initial: State = (0, seed)
    var outcome = run(loop(initial^, TypedStep(count)))
    return outcome.take()._take_ok()


@no_inline
def loop_erased(count: Int, seed: Int) -> Int:
    var initial: State = (0, seed)
    var outcome = run(loop(initial^, ErasedStep(count)))
    return outcome.take()._take_ok()


@fieldwise_init
struct IOStep(OnceUnary):
    """The typed loop's arithmetic as IO tail recursion through flat_map."""
    var limit: Int
    comptime Arg = State
    comptime Out = IO[Int, Int]
    def call_once(deinit self, var value: State) -> IO[Int, Int]:
        if value[0] == self.limit:
            return IO[Int, Int].pure(value[1])
        var next: State = (value[0] + 1, mix(value[1]))
        return IO[State, Int].pure(next^).flat_map(IOStep(self.limit))


@fieldwise_init
struct RaisingStep(OnceUnary):
    """The same loop through a callback that declares the domain error."""
    var limit: Int
    comptime Arg = State
    comptime Out = IO[Int, Int]
    comptime Error = Int
    def call_once(deinit self, var value: State) raises Int -> IO[Int, Int]:
        if value[0] < 0:
            raise value[0]
        if value[0] == self.limit:
            return IO[Int, Int].pure(value[1])
        var next: State = (value[0] + 1, mix(value[1]))
        return IO[State, Int].pure(next^).flat_map(RaisingStep(self.limit))


@no_inline
def loop_io_raising(count: Int, seed: Int) -> Int:
    var initial: State = (0, seed)
    var outcome = run(IO[State, Int].pure(initial^).flat_map(RaisingStep(count)))
    return outcome.take()._take_ok()


@no_inline
def loop_io(count: Int, seed: Int) -> Int:
    var initial: State = (0, seed)
    var outcome = run(IO[State, Int].pure(initial^).flat_map(IOStep(count)))
    return outcome.take()._take_ok()


@fieldwise_init
struct Inc(OnceUnary):
    comptime Arg = Int
    comptime Out = Int
    def call_once(deinit self, var value: Int) -> Int:
        return value + 1


@fieldwise_init
struct Bump(OnceUnary):
    comptime Arg = Int
    comptime Out = IO[Int, Int]
    def call_once(deinit self, var value: Int) -> IO[Int, Int]:
        return IO[Int, Int].pure(value + 1)


@no_inline
def chain_maps(count: Int, seed: Int) -> Int:
    # Build a runtime chain of count maps, then run it.
    var io = IO[Int, Int].pure(seed)
    for _ in range(count):
        io = io^.map(Inc())
    var outcome = run(io^)
    return outcome.take()._take_ok()


@no_inline
def chain_binds(count: Int, seed: Int) -> Int:
    var io = IO[Int, Int].pure(seed)
    for _ in range(count):
        io = io^.flat_map(Bump())
    var outcome = run(io^)
    return outcome.take()._take_ok()


@fieldwise_init
struct Spin(Machine):
    var sink: ArcPointer[List[Int]]
    comptime Value = Int
    comptime Error = Int
    def poll(mut self, context: IOContext[Int]) -> Step[Int, Int]:
        self.sink[][0] = mix(self.sink[][0])
        return .pending(Wait())


@no_inline
def make_typed(sink: ArcPointer[List[Int]]) -> OwnedPointer[Spin]:
    return OwnedPointer(Spin(sink.copy()))


@no_inline
def make_erased(sink: ArcPointer[List[Int]]) -> _ErasedMachine[Int, Int]:
    return _ErasedMachine[Int, Int](Spin(sink.copy()))


@no_inline
def poll_typed(count: Int, seed: Int) -> Int:
    var sink = ArcPointer(List[Int]([seed]))
    var machine = make_typed(sink)
    var context = IOContext[Int](CancellationToken(), False)
    for _ in range(count):
        _ = machine[].poll(context)
    return sink[][0]


@no_inline
def poll_erased(count: Int, seed: Int) -> Int:
    var sink = ArcPointer(List[Int]([seed]))
    var machine = make_erased(sink)
    var context = IOContext[Int](CancellationToken(), False)
    for _ in range(count):
        _ = machine.poll(context)
    return sink[][0]


@no_inline
def frame_typed(count: Int, seed: Int) -> Int:
    # Allocate, poll once and destroy one heap frame per step.
    var sink = ArcPointer(List[Int]([seed]))
    var context = IOContext[Int](CancellationToken(), False)
    for _ in range(count):
        var machine = make_typed(sink)
        _ = machine[].poll(context)
    return sink[][0]


@no_inline
def frame_erased(count: Int, seed: Int) -> Int:
    var sink = ArcPointer(List[Int]([seed]))
    var context = IOContext[Int](CancellationToken(), False)
    for _ in range(count):
        var machine = make_erased(sink)
        _ = machine.poll(context)
    return sink[][0]


@no_inline
def native_loop(count: Int, seed: Int) -> Int:
    var value = seed
    for _ in range(count):
        value = mix(value)
    return value


def median(var samples: List[Int]) -> Int:
    sort(samples)
    return samples[len(samples) // 2]


def measure[f: def(Int, Int) thin -> Int](name: String, count: Int, expected: Int):
    var samples = List[Int]()
    for _ in range(9):
        var start = perf_counter_ns()
        var value = f(count, 7)
        samples.append(Int(perf_counter_ns() - start))
        check(value == expected, name + ": checksum")
    var ns = median(samples^)
    print(name, "count=" + String(count), "median_ns=" + String(ns), "ns_per_step=" + String(Float64(ns) / Float64(count)))


def main():
    comptime LOOP = 65536
    comptime MICRO = 1_000_000
    var loop_expected = native_loop(LOOP, 7)
    var micro_expected = native_loop(MICRO, 7)
    measure[loop_typed]("typed_loop_iteration", LOOP, loop_expected)
    measure[loop_erased]("erased_loop_iteration", LOOP, loop_expected)
    measure[loop_io]("io_loop_iteration", LOOP, loop_expected)
    measure[loop_io_raising]("io_raising_loop_iteration", LOOP, loop_expected)
    measure[chain_maps]("io_map_chain_build_and_run", MICRO, 7 + MICRO)
    measure[chain_binds]("io_bind_chain_build_and_run", MICRO, 7 + MICRO)
    measure[poll_typed]("typed_poll_dispatch", MICRO, micro_expected)
    measure[poll_erased]("erased_poll_dispatch", MICRO, micro_expected)
    measure[frame_typed]("typed_frame_alloc_poll_free", MICRO, micro_expected)
    measure[frame_erased]("erased_frame_alloc_poll_free", MICRO, micro_expected)
