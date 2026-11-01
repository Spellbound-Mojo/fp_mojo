"""Borrowing factories preserve move-only owners across run, failure and abandon."""
from fp.effects import Reader, State, IO, asks, inspect, run, scoped_io, lift_resource, pure_resource, run_io
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct BorrowFactoryOwner(Movable):
    var fail: Bool
    var calls: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def project(value: BorrowFactoryOwner) raises Int -> Int:
    value.calls[] += 1
    if value.fail: raise 71
    return 7


def effect(value: BorrowFactoryOwner) raises Int -> IO[Int].Pure[Int]:
    return IO[Int].pure(project(value))


def observe(value: BorrowFactoryOwner): value.calls[] += 1


def main() raises:
    comptime assert not conforms_to(BorrowFactoryOwner,Copyable)
    var pointer: def(BorrowFactoryOwner) raises Int thin -> Int = project
    var io_pointer: def(BorrowFactoryOwner) raises Int thin -> IO[Int].Pure[Int] = effect
    for operation in range(3):
        for mode in range(3):
            var calls = ArcPointer(0)
            var drops = ArcPointer(0)
            var owner = BorrowFactoryOwner(mode == 1,calls,drops)
            if operation == 0:
                var recipe = asks[Reader[BorrowFactoryOwner]](pointer)
                assert_equal(calls[],0)
                if mode == 2: _ = recipe^
                else:
                    var result = -1
                    try: result = run[Reader[BorrowFactoryOwner]](recipe^,owner)
                    except error: assert_equal(error,71)
                    assert_equal(result,-1 if mode == 1 else 7)
                assert_equal(drops[],0)
                _ = owner^
            elif operation == 1:
                var recipe = inspect[State[BorrowFactoryOwner]](pointer)
                assert_equal(calls[],0)
                if mode == 2:
                    _ = recipe^
                    _ = owner^
                else:
                    var output: Optional[Tuple[Int,BorrowFactoryOwner]] = None
                    try: output = Optional(run[State[BorrowFactoryOwner]](recipe^,owner^))
                    except error: assert_equal(error,71)
                    if mode == 0:
                        var pair = output.take()
                        assert_equal(pair[0],7)
                        assert_equal(drops[],0)
                        _ = pair^
            else:
                var recipe = lift_resource(pure_resource[Int](owner^)).use(scoped_io(io_pointer))
                assert_equal(calls[],0)
                if mode == 2: _ = recipe^
                else:
                    var outcome = run_io(recipe^)
                    assert_equal(outcome.take().is_err(),mode == 1)
            assert_equal(calls[],0 if mode == 2 else 1)
            assert_equal(drops[],1)

    var calls = ArcPointer(0)
    var drops = ArcPointer(0)
    var owner = BorrowFactoryOwner(False,calls,drops)
    var void_pointer: def(BorrowFactoryOwner) thin = observe
    var read = asks[Reader[BorrowFactoryOwner]](void_pointer)
    assert_equal(calls[],0)
    _ = run[Reader[BorrowFactoryOwner]](read^,owner)
    assert_equal(calls[],1)
    assert_equal(drops[],0)
    var state = inspect[State[BorrowFactoryOwner]](void_pointer)
    _ = run[State[BorrowFactoryOwner]](state^,owner^)
    assert_equal(calls[],2)
    assert_equal(drops[],1)
