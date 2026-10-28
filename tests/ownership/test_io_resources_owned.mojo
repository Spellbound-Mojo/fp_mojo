"""Effectful scopes preserve move-only owners, errors and independent origins."""
from std.memory import ArcPointer
from std.testing import assert_equal
from fp.effects import IO, ExitCase, ScopedIO, DelayContract, resource_io_case, delay, run_io
from fp.callables import OnceThunk, OnceUnary
from fp.algebra import pure


@fieldwise_init
struct ScopeOwned(Movable):
    var text: String
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct ScopeOwnedError(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


@fieldwise_init
struct ScopeBorrowedUse[o: ImmOrigin, c: ImmOrigin](OnceThunk):
    var value: Pointer[ScopeOwned, Self.o]
    var expected: Pointer[String, Self.c]
    var errors: ArcPointer[Int]
    comptime Out = Int
    comptime Error = ScopeOwnedError
    def call_once(deinit self) raises Self.Error -> Int:
        if self.value[].text != self.expected[] or self.value[].drops[] != 0:
            raise ScopeOwnedError(99, self.errors^)
        raise ScopeOwnedError(11, self.errors^)


@fieldwise_init
struct ScopeUse[c: ImmOrigin](ScopedIO):
    var expected: Pointer[String, Self.c]
    var errors: ArcPointer[Int]
    comptime Input = ScopeOwned
    comptime Value = Int
    comptime Error = ScopeOwnedError
    comptime Action[o: ImmOrigin] = DelayContract[ScopeBorrowedUse[o, Self.c], ScopeOwnedError].Out
    def build[o: ImmOrigin](deinit self, ref[o] value: ScopeOwned) -> Self.Action[o]:
        return delay[ScopeOwnedError](ScopeBorrowedUse(Pointer(to=value), self.expected, self.errors^))


@fieldwise_init
struct ScopeOwnedCleanup[o: ImmOrigin, c: ImmOrigin](OnceThunk):
    var resource: ScopeOwned
    var exit: Pointer[ExitCase[ScopeOwnedError], Self.o]
    var expected: Pointer[String, Self.c]
    var errors: ArcPointer[Int]
    comptime Out = NoneType
    comptime Error = ScopeOwnedError
    def call_once(deinit self) raises Self.Error -> NoneType:
        if self.resource.text != self.expected[] or self.resource.drops[] != 0 or self.errors[] != 0 or self.exit[].failure().value().errors.first().code != 11:
            raise ScopeOwnedError(99, self.errors^)
        _ = self.resource^
        raise ScopeOwnedError(22, self.errors^)


@fieldwise_init
struct ScopeOwnedFinalizer[c: ImmOrigin](ScopedIO):
    var resource: ScopeOwned
    var expected: Pointer[String, Self.c]
    var errors: ArcPointer[Int]
    comptime Input = ExitCase[ScopeOwnedError]
    comptime Value = NoneType
    comptime Error = ScopeOwnedError
    comptime Action[o: ImmOrigin] = DelayContract[ScopeOwnedCleanup[o, Self.c], ScopeOwnedError].Out
    def build[o: ImmOrigin](deinit self, ref[o] value: Self.Input) -> Self.Action[o]:
        return delay[ScopeOwnedError](ScopeOwnedCleanup(self.resource^, Pointer(to=value), self.expected, self.errors^))


@fieldwise_init
struct ScopeOwnedRelease[c: ImmOrigin](OnceUnary):
    var expected: Pointer[String, Self.c]
    var errors: ArcPointer[Int]
    comptime Arg = ScopeOwned
    comptime Out = ScopeOwnedFinalizer[Self.c]
    def call_once(deinit self, var resource: ScopeOwned) -> Self.Out:
        return ScopeOwnedFinalizer(resource^, self.expected, self.errors^)


def main() raises:
    var resources = ArcPointer(0)
    var errors = ArcPointer(0)
    var expected = String("live until cleanup")
    var owner = ScopeOwned(expected, resources.copy())
    var acquire = pure[IO[ScopeOwnedError]](owner^)
    var release = ScopeOwnedRelease(Pointer(to=expected), errors.copy())
    var scope = resource_io_case(acquire^, release^)
    var program = scope^.use(ScopeUse(Pointer(to=expected), errors.copy()))
    assert_equal(resources[], 0)
    var outcome = run_io(program^)
    assert_equal(resources[], 1)
    assert_equal(errors[], 0)
    var failed = outcome.take()
    var failure = failed^._take_err()
    var stored = failure^.into_errors()
    var values = stored^.into_list()
    assert_equal(len(values), 2)
    assert_equal(values[0].code, 11)
    assert_equal(values[1].code, 22)
    _ = values^
    assert_equal(errors[], 2)
    # Unopened recipes destroy captured owners without running release effects.
    var unopened = resource_io_case(pure[IO[ScopeOwnedError]](ScopeOwned(expected, resources.copy())), ScopeOwnedRelease(Pointer(to=expected), errors.copy()))
    _ = unopened^
    assert_equal(resources[], 2)
    assert_equal(errors[], 2)
