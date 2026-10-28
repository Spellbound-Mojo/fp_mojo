"""Effectful resource handoff, rollback, exit observation and composition."""
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from fp.effects import IO, ExitCase, ScopedIO, DelayContract, Poll, CancellationToken, resource_io, resource_io_case, resource_io_full, resource_io_case_full, eval_resource, lift_resource, pure_resource, delay, run_io
from fp.callables import OnceThunk, OnceUnary
from fp.algebra import pure


@fieldwise_init
struct ResourceStep(OnceThunk):
    var log: ArcPointer[List[Int]]
    var token: CancellationToken
    var step: Int
    var fail: Bool
    var cancel: Bool
    comptime Out = Int
    comptime Error = Int
    def call_once(deinit self) raises Int -> Int:
        self.log[].append(self.step)
        if self.cancel:
            self.token.cancel()
        if self.fail:
            raise self.step
        return self.step


@fieldwise_init
struct ResourceObserve[o: ImmOrigin](OnceThunk):
    var exit: Pointer[ExitCase[Int], Self.o]
    var step: ResourceStep
    comptime Out = Int
    comptime Error = Int
    def call_once(deinit self) raises Int -> Int:
        if self.exit[].is_error():
            self.step.log[].append(100 + self.exit[].failure().value().errors.first())
        if self.exit[].is_canceled():
            self.step.log[].append(200)
        return self.step^.call_once()


@fieldwise_init
struct ResourceObserveFactory(ScopedIO):
    var step: ResourceStep
    var fail: Bool
    comptime Input = ExitCase[Int]
    comptime Value = Int
    comptime Error = Int
    comptime BuildError = Int
    comptime Action[o: ImmOrigin] = DelayContract[ResourceObserve[o], Int].Out
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) raises Int -> Self.Action[o]:
        if self.fail:
            raise 41
        return delay[Int](ResourceObserve(Pointer(to=value), self.step^))


@fieldwise_init
struct ResourceRelease(OnceUnary):
    var step: ResourceStep
    var fail: Int
    comptime Arg = Int
    comptime Out = ResourceObserveFactory
    comptime Error = Int
    def call_once(deinit self, var value: Int) raises Int -> Self.Out:
        if self.fail == 1:
            raise 40
        return ResourceObserveFactory(self.step^, self.fail == 2)


@fieldwise_init
struct ResourceUse(ScopedIO):
    var step: ResourceStep
    var fail: Bool
    comptime Input = Int
    comptime Value = Int
    comptime Error = Int
    comptime BuildError = Int
    comptime Action[o: ImmOrigin] = DelayContract[ResourceStep, Int].Out
    def build[o: ImmOrigin](deinit self, ref[o] value: Int) raises Int -> Self.Action[o]:
        if self.fail:
            raise 30
        return delay[Int](self.step^)


def resource_matrix() raises:
    # Default acquisition must hand off a successful owner before cancellation.
    for acquire_fail in range(2):
        for acquire_cancel in range(2):
            for body_fail in range(2):
                for body_cancel in range(2):
                    for release_fail in range(2):
                        for release_cancel in range(2):
                            var log = ArcPointer(List[Int]())
                            var token = CancellationToken()
                            var acquire = delay[Int](ResourceStep(log.copy(), token.copy(), 1, Bool(acquire_fail), Bool(acquire_cancel)))
                            var release = ResourceRelease(ResourceStep(log.copy(), token.copy(), 3, Bool(release_fail), Bool(release_cancel)), 0)
                            var scope = resource_io_case(acquire^, release^)
                            var use = ResourceUse(ResourceStep(log.copy(), token.copy(), 2, Bool(body_fail), Bool(body_cancel)), False)
                            var program = scope^.use(use^)
                            assert_equal(len(log[]), 0)
                            var outcome = run_io(program^, token)
                            var expected_log = List[Int]([1])
                            var errors = List[Int]()
                            var canceled = Bool(acquire_cancel)
                            if acquire_fail:
                                errors.append(1)
                            else:
                                if not acquire_cancel:
                                    expected_log.append(2)
                                    if body_fail:
                                        errors.append(2)
                                        expected_log.append(102)
                                    canceled = Bool(body_cancel)
                                if canceled:
                                    expected_log.append(200)
                                expected_log.append(3)
                                if release_fail:
                                    errors.append(3)
                                canceled = canceled or Bool(release_cancel)
                            assert_equal(log[], expected_log)
                            if len(errors):
                                var failed = outcome.take()
                                var failure = failed^._take_err()
                                assert_equal(failure.canceled, canceled)
                                var stored = failure^.into_errors()
                                assert_equal(stored^.into_list(), errors)
                            elif canceled:
                                assert_true(not outcome)
                            else:
                                var result = outcome.take()
                                assert_equal(result^._take_ok(), 2)


def resource_construction_errors() raises:
    for failure_stage in range(1, 3):
        var log = ArcPointer(List[Int]())
        var token = CancellationToken()
        var release = ResourceRelease(ResourceStep(log.copy(), token.copy(), 3, False, False), failure_stage)
        var scope = resource_io_case(pure[IO[Int]](1), release^)
        var result = run_io(scope^.use(ResourceUse(ResourceStep(log.copy(), token.copy(), 2, False, False), True)))
        var failed = result.take()
        var failure = failed^._take_err()
        var errors = failure^.into_errors()
        assert_equal(errors^.into_list(), [30, 39 + failure_stage])
        assert_equal(len(log[]), 0)


def resource_nested() raises:
    for fail in range(3):
        var log = ArcPointer(List[Int]())
        var token = CancellationToken()
        var left = resource_io_case(delay[Int](ResourceStep(log.copy(), token.copy(), 1, False, False)), ResourceRelease(ResourceStep(log.copy(), token.copy(), 4, True, False), 0))
        var right = resource_io_case(delay[Int](ResourceStep(log.copy(), token.copy(), 2, fail == 1, fail == 2)), ResourceRelease(ResourceStep(log.copy(), token.copy(), 3, True, False), 0))
        var result = run_io(left^.product(right^).surround(pure[IO[Int]](42)), token)
        var failed = result.take()
        var failure = failed^._take_err()
        var errors = failure^.into_errors()
        if fail == 1:
            assert_equal(errors^.into_list(), [2, 4])
            assert_equal(log[], [1, 2, 102, 4])
        elif fail == 2:
            assert_equal(errors^.into_list(), [3, 4])
            assert_equal(log[], [1, 2, 200, 3, 103, 200, 4])
        else:
            assert_equal(errors^.into_list(), [3, 4])
            assert_equal(log[], [1, 2, 3, 103, 4])


@fieldwise_init
struct ResourceFull(OnceUnary):
    var step: ResourceStep
    var cancel: Bool
    comptime Arg = Poll[Int]
    comptime Out = Poll[Int].Applied[DelayContract[ResourceStep, Int].Out]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        if self.cancel:
            self.step.token.cancel()
        return poll.apply(delay[Int](self.step^))


@fieldwise_init
struct ResourceFullMasked(OnceUnary):
    var step: ResourceStep
    comptime Arg = Poll[Int]
    comptime Out = DelayContract[ResourceStep, Int].Out
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        return delay[Int](self.step^)


def resource_full() raises:
    var log = ArcPointer(List[Int]())
    var token = CancellationToken()
    var factory = ResourceFull(ResourceStep(log.copy(), token.copy(), 1, False, False), True)
    var scope = resource_io_case_full[Int](factory^, ResourceRelease(ResourceStep(log.copy(), token.copy(), 3, False, False), 0))
    assert_true(not run_io(scope^.surround(pure[IO[Int]](2)), token))
    assert_equal(len(log[]), 0)
    token = CancellationToken()
    var masked = ResourceFullMasked(ResourceStep(log.copy(), token.copy(), 1, False, True))
    var protected = resource_io_case_full[Int](masked^, ResourceRelease(ResourceStep(log.copy(), token.copy(), 3, False, False), 0))
    assert_true(not run_io(protected^.surround(pure[IO[Int]](2)), token))
    assert_equal(log[], [1, 200, 3])


def resource_native_release(var value: Int) -> IO[Int].Pure[NoneType]:
    var unit: NoneType = None
    return pure[IO[Int]](unit)


def resource_native_effect(value: Int) -> IO[Int].Pure[Int]:
    return pure[IO[Int]](value * 2)


def resource_native_project(value: Int) -> Int:
    return value + 1


def resource_native_bind(value: Int) -> type_of(pure_resource[Int](0)):
    return pure_resource[Int](value + 2)


def resource_native_acquire(var poll: Poll[Int]) -> IO[Int].Pure[Int]:
    return pure[IO[Int]](5)


def resource_adapters() raises:
    var scope = resource_io_full[Int](resource_native_acquire, resource_native_release)
    var result = run_io(scope^.map(resource_native_project).flat_map(resource_native_bind).eval_map(resource_native_effect).eval_tap(resource_native_effect).use(resource_native_effect))
    var success = result.take()
    assert_equal(success^._take_ok(), 32)
    var evaluated = eval_resource(pure[IO[Int]](7))
    var lifted = lift_resource(pure_resource[Int](8))
    var pair = evaluated^.product(lifted^)
    var surrounded = run_io(pair^.surround(pure[IO[Int]](42)))
    var used = surrounded.take()
    assert_equal(used^._take_ok(), 42)
    var log = ArcPointer(List[Int]())
    var token = CancellationToken()
    var canceled_eval = eval_resource(delay[Int](ResourceStep(log.copy(), token.copy(), 1, False, True)))
    assert_true(not run_io(canceled_eval^.use(resource_native_effect), token))
    assert_equal(log[], [1])
    for keep in range(2):
        log[] = List[Int]()
        token = CancellationToken()
        var scope = resource_io_case(pure[IO[Int]](1), ResourceRelease(ResourceStep(log.copy(), token.copy(), 3, False, False), 0))
        var use = ResourceUse(ResourceStep(log.copy(), token.copy(), 2, False, True), False)
        if keep:
            assert_true(not run_io(scope^.eval_tap(use^).surround(pure[IO[Int]](9)), token))
        else:
            assert_true(not run_io(scope^.eval_map(use^).surround(pure[IO[Int]](9)), token))
        assert_equal(log[], [2, 200, 3])


def main() raises:
    resource_matrix()
    resource_construction_errors()
    resource_nested()
    resource_full()
    resource_adapters()
    resource_retained_poll()
    resource_native_failures()


@fieldwise_init
struct ResourceRetainPoll(OnceUnary):
    var token: CancellationToken
    comptime Arg = Poll[Int]
    comptime Out = IO[Int].Pure[Poll[Int]]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        self.token.cancel()
        return pure[IO[Int]](poll^)


@fieldwise_init
struct ResourceReleasePoll(OnceUnary):
    var step: ResourceStep
    comptime Arg = Poll[Int]
    comptime Out = Poll[Int].Applied[DelayContract[ResourceStep, Int].Out]
    def call_once(deinit self, var poll: Self.Arg) -> Self.Out:
        return poll.apply(delay[Int](self.step^))


def resource_retained_poll() raises:
    var log = ArcPointer(List[Int]())
    var token = CancellationToken()
    var scope = resource_io_full[Int](ResourceRetainPoll(token.copy()), ResourceReleasePoll(ResourceStep(log.copy(), token.copy(), 3, False, False)))
    assert_true(not run_io(scope^.surround(pure[IO[Int]](2)), token))
    # An acquisition Poll cannot remove the fresh release mask.
    assert_equal(log[], [3])


def resource_native_fail_release(var value: Int) raises Int -> IO[Int].Pure[NoneType]:
    raise 55


def resource_native_fail_acquire(var poll: Poll[Int]) raises Int -> IO[Int].Pure[Int]:
    raise 66


def resource_native_failures() raises:
    var scope = resource_io(pure[IO[Int]](1), resource_native_fail_release)
    var result = run_io(scope^.use(resource_native_effect))
    var failed = result.take()
    var failure = failed^._take_err()
    var errors = failure^.into_errors()
    assert_equal(errors^.into_list(), [55])
    var full = resource_io_full[Int](resource_native_fail_acquire, resource_native_fail_release)
    var result_full = run_io(full^.use(resource_native_effect))
    var failed_full = result_full.take()
    var failure_full = failed_full^._take_err()
    var errors_full = failure_full^.into_errors()
    assert_equal(errors_full^.into_list(), [66])
