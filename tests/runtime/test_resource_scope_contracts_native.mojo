"""Native and raising factories retain signatures and execution timing."""
from fp.effects import IO, IOContract, Outcome, resource_io, scoped_io, lift_resource, pure_resource
from fp.functions import pipeline
from fp.algebra import pure
from std.memory import ArcPointer
from std.testing import assert_equal


def describe(value: Int) -> IO[Int].Pure[String]: return pure[IO[Int]](String(value))
def echo(value: String) -> IO[Int].Pure[String]: return pure[IO[Int]](value.copy())
def rejected(value: Int) raises Int -> IO[Int].Pure[String]: raise value


def check_failure[V: Movable & Deinitable](var outcome: Outcome[V,Int]) raises:
    var failed = outcome.take()
    var error = failed^._take_err()
    assert_equal(error^.into_errors().into_list(),List[Int]([71]))


def main() raises:
    var direct = pipeline(lift_resource(pure_resource[Int](7)).use(describe)).run_io()
    assert_equal(direct.take()._ok().value,"7")
    var mapped = lift_resource(pure_resource[Int](8)).eval_map(describe)
    var projected = pipeline(mapped^.use(echo)).run_io()
    assert_equal(projected.take()._ok().value,"8")
    var tapped = lift_resource(pure_resource[Int](9)).eval_tap(describe)
    var observed = pipeline(tapped^.use(describe)).run_io()
    assert_equal(observed.take()._ok().value,"9")
    for operation in range(3):
        var calls = ArcPointer(0)
        def counted(value: Int) {calls} -> IO[Int].Pure[String]:
            calls[] += 1
            return pure[IO[Int]](String(value))
        var scope = lift_resource(pure_resource[Int](11))
        if operation == 0:
            var pending = scope^.use(counted)
            assert_equal(calls[],0)
            _ = pipeline(pending^).run_io()
        elif operation == 1:
            var pending = scope^.eval_map(counted).use_void()
            assert_equal(calls[],0)
            _ = pipeline(pending^).run_io()
        else:
            var pending = scope^.eval_tap(counted).use_void()
            assert_equal(calls[],0)
            _ = pipeline(pending^).run_io()
        assert_equal(calls[],1)
    comptime for operation in range(3):
        var scope = lift_resource(pure_resource[Int](71))
        comptime if operation == 0:
            check_failure(pipeline(scope^.use(rejected)).run_io())
        elif operation == 1:
            check_failure(pipeline(scope^.eval_map(rejected).use_void()).run_io())
        else:
            check_failure(pipeline(scope^.eval_tap(rejected).use_void()).run_io())
