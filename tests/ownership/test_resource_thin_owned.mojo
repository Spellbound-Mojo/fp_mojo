"""Thin factories borrow move-only resources and do not execute on abandonment."""
from fp.effects import IO, lift_resource, pure_resource, run_io
from fp.algebra import pure
from std.memory import ArcPointer
from std.testing import assert_equal


@fieldwise_init
struct Owner(Movable):
    var fail: Bool
    var calls: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __deinit__(deinit self): self.drops[] += 1


def inspect(value: Owner) raises Int -> IO[Int].Pure[Int]:
    value.calls[] += 1
    if value.fail: raise 71
    return pure[IO[Int]](7)


def main() raises:
    var pointer: def(Owner) raises Int thin -> IO[Int].Pure[Int] = inspect
    comptime for operation in range(3):
        for mode in range(3):
            var calls = ArcPointer(0)
            var drops = ArcPointer(0)
            var scope = lift_resource(pure_resource[Int](Owner(mode == 1,calls,drops)))
            comptime if operation == 0:
                var pending = scope^.use(pointer)
                assert_equal(calls[],0)
                assert_equal(drops[],0)
                if mode == 2: _ = pending^
                else: _ = run_io(pending^)
            elif operation == 1:
                var pending = scope^.eval_map(pointer).use_void()
                assert_equal(calls[],0)
                assert_equal(drops[],0)
                if mode == 2: _ = pending^
                else: _ = run_io(pending^)
            else:
                var pending = scope^.eval_tap(pointer).use_void()
                assert_equal(calls[],0)
                assert_equal(drops[],0)
                if mode == 2: _ = pending^
                else: _ = run_io(pending^)
            assert_equal(calls[],0 if mode == 2 else 1)
            assert_equal(drops[],1)
