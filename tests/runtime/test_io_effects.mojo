"""IO composes through existing families and finalizes errors and cancellation."""
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from fp.callables import OnceThunk, Unary
from fp.algebra import map, flat_map, pure, tail_rec_m
from fp.effects.io import IO, delay, run_io, guarantee, canceled, uncancelable, sleep_io, CancellationToken, use_resource, capture_io
from fp.effects.resources import resource
from fp.effects.outcomes import EffectFailure, Outcome
from fp.data import ControlFlow, Continue, Break

@fieldwise_init
struct IOTestFailure(Movable):
    var code: Int

@fieldwise_init
struct IOTestStep(OnceThunk):
    var value: Int
    var fail: Bool
    var log: ArcPointer[List[Int]]
    comptime Out = Int
    comptime Error = IOTestFailure
    def call_once(deinit self) raises Self.Error -> Int:
        self.log[].append(self.value)
        if self.fail:
            raise IOTestFailure(self.value)
        return self.value

def io_double(value: Int) -> Int: return value * 2

def io_map_failure(value: Int) raises IOTestFailure -> Int:
    raise IOTestFailure(value + 10)

@fieldwise_init
struct IOCount(OnceThunk):
    var count: Int
    comptime Out = ControlFlow[Int, Int]
    def call_once(deinit self) -> Self.Out:
        if self.count == 100000:
            return Break(self.count)
        return Continue(self.count + 1)

@fieldwise_init
struct IOCountStep(Unary):
    comptime Arg = Int
    comptime Out = type_of(delay[IOTestFailure](IOCount(0)))
    def call(self, var value: Int) -> Self.Out:
        return delay[IOTestFailure](IOCount(value))

def io_resource_open() -> Int: return 21
def io_resource_close(var value: Int): pass

@fieldwise_init
struct IORecovery(Unary):
    var log: ArcPointer[List[Int]]
    comptime Arg = EffectFailure[IOTestFailure]
    comptime Out = IO[IOTestFailure].Pure[Int]
    def call(self, var failure: Self.Arg) -> Self.Out:
        self.log[].append(88)
        return pure[IO[IOTestFailure]](7)


@fieldwise_init
struct IOAfterCancel(Unary):
    var log: ArcPointer[List[Int]]
    comptime Arg = NoneType
    comptime Out = IO[IOTestFailure].Pure[Int]
    def call(self, var unit: NoneType) -> Self.Out:
        self.log[].append(55)
        return pure[IO[IOTestFailure]](55)


def main() raises:
    var log = ArcPointer(List[Int]())
    var program = map[IO[IOTestFailure]](delay[IOTestFailure](IOTestStep(21, False, log.copy())), io_double)
    assert_equal(len(log[]), 0)
    var output = run_io(program^)
    var result = output.take()
    assert_equal(result^._take_ok(), 42)
    assert_equal(log[], [21])
    log[] = List[Int]()
    var failed_map = map[IO[IOTestFailure]](delay[IOTestFailure](IOTestStep(1, False, log.copy())), io_map_failure)
    var finalized = run_io(guarantee(failed_map^, delay[IOTestFailure](IOTestStep(2, True, log.copy()))))
    assert_equal(log[], [1, 2])
    var failed = finalized.take()
    var failure = failed^._take_err()
    var stored = failure^.into_errors()
    var errors = stored^.into_list()
    assert_equal(errors[0].code, 11)
    assert_equal(errors[1].code, 2)

    log[] = List[Int]()
    var nested = guarantee(guarantee(canceled[IOTestFailure](), delay[IOTestFailure](IOTestStep(1, False, log.copy()))), delay[IOTestFailure](IOTestStep(2, False, log.copy())))
    assert_true(not run_io(nested^))
    assert_equal(log[], [1, 2])
    log[] = List[Int]()
    var token = CancellationToken()
    token.cancel()
    var unopened = guarantee(delay[IOTestFailure](IOTestStep(1, False, log.copy())), delay[IOTestFailure](IOTestStep(2, False, log.copy())))
    assert_true(not run_io(unopened^, token))
    assert_equal(len(log[]), 0)
    assert_true(not run_io(uncancelable(canceled[IOTestFailure]())))
    assert_true(Bool(run_io(sleep_io[IOTestFailure](0.0))))
    var invalid_sleep = False
    try:
        _ = sleep_io[IOTestFailure](-1.0)
    except:
        invalid_sleep = True
    assert_true(invalid_sleep)

    var looped = run_io(tail_rec_m[IO[IOTestFailure]](0, IOCountStep()))
    var counted = looped.take()
    assert_equal(counted^._take_ok(), 100000)
    var scoped = run_io(use_resource(resource[IOTestFailure](io_resource_open, io_resource_close), io_double))
    var scoped_result = scoped.take()
    assert_equal(scoped_result^._take_ok(), 42)

    log[] = List[Int]()
    var mapped_error = map[IO[IOTestFailure]](pure[IO[IOTestFailure]](1), io_map_failure)
    var recovered = run_io(IO[IOTestFailure].or_else(IORecovery(log.copy()), capture_io(mapped_error^)))
    var recovered_result = recovered.take()
    assert_equal(recovered_result^._take_ok(), 7)
    assert_equal(log[], [88])
    log[] = List[Int]()
    var canceled_value = IO[IOTestFailure].lift(Outcome[Int, IOTestFailure]())
    assert_true(not run_io(IO[IOTestFailure].or_else(IORecovery(log.copy()), canceled_value^)))
    assert_equal(len(log[]), 0)

    log[] = List[Int]()
    var masked_steps = flat_map[IO[IOTestFailure]](canceled[IOTestFailure](), IOAfterCancel(log.copy()))
    assert_true(not run_io(uncancelable(masked_steps^)))
    assert_equal(log[], [55])
    log[] = List[Int]()
    var unmasked_steps = flat_map[IO[IOTestFailure]](canceled[IOTestFailure](), IOAfterCancel(log.copy()))
    assert_true(not run_io(unmasked_steps^))
    assert_equal(len(log[]), 0)
