"""Keyword no-value callbacks retain literal witnesses through generic forwarding."""
from fp.data import Capture, Result, raise_on_err
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct AttemptVoidFailure(Movable):
    var code: Int

@fieldwise_init
struct AttemptVoidToken(Movable):
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1


def capture_pure[K: Movable & Deinitable, R: Movable & Deinitable, //,
                 F: def(var **kwargs: K) -> R](function: F, /, var **values: K) -> Result[R, Never]:
    return Capture.kwargs(**values^).run(function)


def capture_raising[K: Movable & Deinitable, R: Movable & Deinitable,
                    E: Movable & Deinitable, //,
                    F: def(var **kwargs: K) raises E -> R](function: F, /, var **values: K) -> Result[R, E]:
    return Capture[E].kwargs(**values^).run(function)


def explicit_value(var **values: Int) -> NoneType:
    _ = len(values)
    return None


def main() raises:
    var calls = 0
    def pure(var **values: Int) {mut calls}:
        calls += 1 + len(values)
    var empty = Capture.kwargs[K=Int]().run(pure)
    comptime assert type_of(empty) == Result[type_of(None), Never]
    assert_equal(empty.is_ok(), True)
    var forwarded = capture_pure(pure, function=1, first=2, values=3)
    comptime assert type_of(forwarded) == Result[type_of(None), Never]
    assert_equal(forwarded.is_ok(), True)
    assert_equal(calls, 5)

    def raising(var **values: Int) raises AttemptVoidFailure {mut calls} -> None:
        calls += 1
        if len(values): raise AttemptVoidFailure(len(values))
    var ok = capture_raising(raising)
    comptime assert type_of(ok) == Result[type_of(None), AttemptVoidFailure]
    assert_equal(ok.is_ok(), True)
    var failed = capture_raising(raising, one=1, two=2)
    comptime assert type_of(failed) == Result[type_of(None), AttemptVoidFailure]
    var code = 0
    try: _ = raise_on_err(failed^)
    except error: code = error.code
    assert_equal(code, 2)
    assert_equal(calls, 7)

    def never(var **values: Int) raises Never {mut calls}:
        calls += 1 + len(values)
    var unreachable = capture_raising(never, one=1)
    comptime assert type_of(unreachable) == Result[type_of(None), Never]
    assert_equal(unreachable.is_ok(), True)
    assert_equal(calls, 9)

    def stopped(var **values: Int) raises StopIteration {mut calls}:
        calls += 1 + len(values)
        raise StopIteration()
    var stop = Capture[StopIteration].kwargs[K=Int]().run(stopped)
    comptime assert type_of(stop) == Result[type_of(None), StopIteration]
    assert_equal(stop.is_err(), True)
    assert_equal(calls, 10)

    var explicit = Capture.kwargs[K=Int]().run(explicit_value)
    comptime assert type_of(explicit) == Result[NoneType, Never]
    assert_equal(explicit.is_ok(), True)

    var drops = ArcPointer(0)
    def consume(var **values: AttemptVoidToken) {mut calls}:
        calls += len(values)
    var first = AttemptVoidToken(drops)
    var second = AttemptVoidToken(drops)
    var consumed = capture_pure(consume, first=first^, second=second^)
    assert_equal(consumed.is_ok(), True)
    assert_equal(drops[], 2)
    assert_equal(calls, 12)

    def reject_owned(var **values: AttemptVoidToken) raises AttemptVoidFailure {mut calls}:
        calls += len(values)
        raise AttemptVoidFailure(len(values))
    var last = AttemptVoidToken(drops)
    var rejected = capture_raising(reject_owned, last=last^)
    assert_equal(drops[], 3)
    code = 0
    try: _ = raise_on_err(rejected^)
    except error: code = error.code
    assert_equal(code, 1)
    assert_equal(calls, 13)
