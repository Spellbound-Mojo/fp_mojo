"""Exit observers and lexical Poll restoration preserve cancellation and errors."""
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from fp.effects import IO, IOContext, ExitCase, ScopedIO, DelayContract, Poll, CancellationToken, delay, run_io, canceled, uncancelable, uncancelable_with, guarantee, guarantee_case, on_cancel, scoped_io
from fp.callables import OnceThunk, OnceUnary
from fp.algebra import pure


@fieldwise_init
struct FinalizationObserve[o: ImmOrigin](OnceThunk):
    var exit: Pointer[ExitCase[Int], Self.o]
    var log: ArcPointer[List[Int]]
    var fail: Bool
    comptime Out = NoneType
    comptime Error = Int
    def call_once(deinit self) raises Int -> NoneType:
        if self.exit[].is_error():
            self.log[].append(self.exit[].failure().value().errors.first())
        elif self.exit[].is_success():
            self.log[].append(1)
        if self.exit[].is_canceled():
            self.log[].append(3)
        if self.fail:
            raise 22
        return None


@fieldwise_init
struct FinalizationObserver(ScopedIO):
    var log: ArcPointer[List[Int]]
    var fail: Bool
    var build_fail: Bool
    comptime Input = ExitCase[Int]
    comptime Value = NoneType
    comptime Error = Int
    comptime BuildError = Int
    comptime Action[o: ImmOrigin] = DelayContract[FinalizationObserve[o], Int].Out
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) raises Int -> Self.Action[o]:
        if self.build_fail:
            raise 33
        return delay[Int](FinalizationObserve(Pointer(to=value), self.log^, self.fail))


@fieldwise_init
struct FinalizationStep(OnceThunk):
    var log: ArcPointer[List[Int]]
    var token: CancellationToken
    var cancel: Bool
    var fail: Bool
    comptime Out = Int
    comptime Error = Int
    def call_once(deinit self) raises Int -> Int:
        self.log[].append(7)
        if self.cancel:
            self.token.cancel()
        if self.fail:
            raise 11
        return 42


@fieldwise_init
struct FinalizationPollBody(OnceUnary):
    var log: ArcPointer[List[Int]]
    var token: CancellationToken
    comptime Arg = Poll[Int]
    comptime Out = Poll[Int].Applied[DelayContract[FinalizationStep, Int].Out]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        self.token.cancel()
        return poll.apply(delay[Int](FinalizationStep(self.log^, self.token^, False, False)))


def finalization_native(exit: ExitCase[Int]) -> IO[Int].Pure[NoneType]:
    var unit: NoneType = None
    return pure[IO[Int]](unit)


def main() raises:
    var legacy_context = IOContext[Int](_token=CancellationToken(), _masked=False)
    assert_true(not legacy_context.canceled())
    finalization_mask_exit()
    finalization_escaped_poll()
    for cancel in range(2):
        for fail in range(2):
            for cleanup_fail in range(2):
                var log = ArcPointer(List[Int]())
                var token = CancellationToken()
                var body = delay[Int](FinalizationStep(log.copy(), token.copy(), Bool(cancel), Bool(fail)))
                var program = guarantee_case(body^, FinalizationObserver(log.copy(), Bool(cleanup_fail), False))
                assert_equal(len(log[]), 0)
                var result = run_io(program^, token)
                var expected = List[Int]([7])
                if fail:
                    expected.append(11)
                elif not cancel:
                    expected.append(1)
                if cancel:
                    expected.append(3)
                assert_equal(log[], expected)
                if fail or cleanup_fail:
                    var failed = result.take()
                    var failure = failed^._take_err()
                    assert_equal(failure.canceled, Bool(cancel))
                    var errors = failure^.into_errors()
                    var values = errors^.into_list()
                    assert_equal(len(values), fail + cleanup_fail)
                    if fail:
                        assert_equal(values[0], 11)
                    if cleanup_fail:
                        assert_equal(values[len(values) - 1], 22)
                elif cancel:
                    assert_true(not result)
                else:
                    var success = result.take()
                    assert_equal(success^._take_ok(), 42)

    var log = ArcPointer(List[Int]())
    var token = CancellationToken()
    var body = delay[Int](FinalizationStep(log.copy(), token.copy(), False, True))
    var result = run_io(guarantee_case(body^, FinalizationObserver(log.copy(), False, True)))
    var failed = result.take()
    var failure = failed^._take_err()
    var errors = failure^.into_errors()
    assert_equal(errors^.into_list(), [11, 33])
    assert_equal(log[], [7])

    var native = run_io(guarantee_case(pure[IO[Int]](9), scoped_io(finalization_native)))
    var success = native.take()
    assert_equal(success^._take_ok(), 9)

    for cancel in range(2):
        for fail in range(2):
            log[] = List[Int]()
            token = CancellationToken()
            var body = delay[Int](FinalizationStep(log.copy(), token.copy(), Bool(cancel), Bool(fail)))
            var cleanup = delay[Int](FinalizationStep(log.copy(), token.copy(), False, False))
            _ = run_io(on_cancel(body^, cleanup^), token)
            assert_equal(len(log[]), 1 + cancel)

    # A pending request is observed inside Poll, before its delayed callback.
    log[] = List[Int]()
    token = CancellationToken()
    var polled = uncancelable_with[Int](FinalizationPollBody(log.copy(), token.copy()))
    assert_true(not run_io(polled^, token))
    assert_equal(len(log[]), 0)

    # Restoring an enclosing mask does not make an inner region cancelable.
    token = CancellationToken()
    var nested = uncancelable_with[Int](FinalizationPollBody(log.copy(), token.copy()))
    assert_true(not run_io(uncancelable(nested^), token))
    assert_equal(log[], [7])

    # Already canceled programs never enter or finalize their scope.
    log[] = List[Int]()
    token.cancel()
    var unopened = guarantee_case(pure[IO[Int]](1), FinalizationObserver(log.copy(), False, False))
    assert_true(not run_io(unopened^, token))
    assert_equal(len(log[]), 0)


@fieldwise_init
struct FinalizationReturnPoll(OnceUnary):
    comptime Arg = Poll[Int]
    comptime Out = IO[Int].Pure[Poll[Int]]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        return pure[IO[Int]](poll^)


@fieldwise_init
struct FinalizationForeignPoll(OnceUnary):
    var retained: Poll[Int]
    var log: ArcPointer[List[Int]]
    var token: CancellationToken
    comptime Arg = Poll[Int]
    comptime Out = Poll[Int].Applied[DelayContract[FinalizationStep, Int].Out]
    def call_once(deinit self, var current: Self.Arg) -> Self.Out:
        self.token.cancel()
        return self.retained.apply(delay[Int](FinalizationStep(self.log^, self.token^, False, False)))


def finalization_escaped_poll() raises:
    var outcome = run_io(uncancelable_with[Int](FinalizationReturnPoll()))
    var success = outcome.take()
    var retained = success^._take_ok()
    var token = CancellationToken()
    var log = ArcPointer(List[Int]())
    var body = uncancelable_with[Int](FinalizationForeignPoll(retained^, log.copy(), token.copy()))
    assert_true(not run_io(body^, token))
    assert_equal(log[], [7])


@fieldwise_init
struct FinalizationContinuation(OnceUnary):
    var log: ArcPointer[List[Int]]
    comptime Arg = Int
    comptime Out = IO[Int].Pure[Int]
    def call_once(deinit self, var value: Int) -> Self.Out:
        self.log[].append(99)
        return pure[IO[Int]](value)


@fieldwise_init
struct FinalizationMaskedRequest(OnceUnary):
    var token: CancellationToken
    comptime Arg = Poll[Int]
    comptime Out = IO[Int].Pure[Int]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        self.token.cancel()
        return pure[IO[Int]](42)


def finalization_mask_exit() raises:
    from fp.algebra import flat_map
    var log = ArcPointer(List[Int]())
    var token = CancellationToken()
    var masked = uncancelable(delay[Int](FinalizationStep(log.copy(), token.copy(), True, False)))
    var followed = flat_map[IO[Int]](FinalizationContinuation(log.copy()), masked^)
    assert_true(not run_io(followed^, token))
    assert_equal(log[], [7])

    log[] = List[Int]()
    token = CancellationToken()
    var cleanup = delay[Int](FinalizationStep(log.copy(), token.copy(), True, False))
    var finalized = guarantee(pure[IO[Int]](42), cleanup^)
    var after_cleanup = flat_map[IO[Int]](FinalizationContinuation(log.copy()), finalized^)
    assert_true(not run_io(after_cleanup^, token))
    assert_equal(log[], [7])

    log[] = List[Int]()
    token = CancellationToken()
    var scoped = uncancelable_with[Int](FinalizationMaskedRequest(token.copy()))
    var after_factory = flat_map[IO[Int]](FinalizationContinuation(log.copy()), scoped^)
    assert_true(not run_io(after_factory^, token))
    assert_equal(len(log[]), 0)
