"""Native fold error channels, exact pulls, and empty/singleton boundaries."""
from fp.iteration import reduce, fold_until, ReductionError, ReductionStepError, EmptyReductionError
from fp.data import ControlFlow, Continue, Break
from std.iter import Iterator
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Source(Iterator):
    comptime Element = Int
    var length: Int
    var pulls: ArcPointer[Int]
    def __next__(mut self) raises StopIteration -> Int:
        self.pulls[] += 1
        if self.pulls[] > self.length:
            raise StopIteration()
        return self.pulls[]

@fieldwise_init
struct Failure(Copyable, Writable):
    var code: Int

@fieldwise_init
struct Halt(Copyable):
    var item: Int

def exercise(library: Bool, mode: Int, length: Int, fail_at: Int, stop_at: Int,
             pulls: ArcPointer[Int], trace: ArcPointer[List[Int]]) -> Int:
    def step(var acc: Int, var item: Int) raises Failure {fail_at, trace} -> Int:
        trace[].append(100 * acc + item)
        if item == fail_at:
            raise Failure(item)
        return acc - item
    def control(var acc: Int, var item: Int) raises Failure {fail_at, stop_at, trace} -> ControlFlow[Halt, Int]:
        trace[].append(100 * acc + item)
        if item == fail_at:
            raise Failure(item)
        if item == stop_at:
            return ControlFlow[Halt, Int](Break(Halt(item)))
        return ControlFlow[Halt, Int](Continue(acc - item))
    var source = Source(length, pulls)
    if library and mode == 1:
        try:
            return reduce(step, source^)
        except error:
            if error.isa[EmptyReductionError]():
                return -900
            return -1000 - error^.unwrap[ReductionStepError[Failure]]().into_error().code
    try:
        if library and mode == 0:
            return reduce(step, source^, initial=20)
        if library:
            var result = fold_until(control, 20, source^)
            if result.isa[Break[Halt]]():
                return 2000 + result^.unwrap[Break[Halt]]().into_payload().item
            return result^.unwrap[Continue[Int]]().into_payload()
        var acc = 20
        if mode == 1:
            try:
                acc = source.__next__()
            except:
                return -900
        while True:
            var item: Int
            try:
                item = source.__next__()
            except:
                return acc
            if mode == 2:
                var result = control(acc, item)
                if result.isa[Break[Halt]]():
                    return 2000 + result^.unwrap[Break[Halt]]().into_payload().item
                acc = result^.unwrap[Continue[Int]]().into_payload()
            else:
                acc = step(acc, item)
    except error:
        return -1000 - error.code

def stop(var acc: Int, var item: Int) raises StopIteration -> Int:
    raise StopIteration()

def stop_control(var acc: Int, var item: Int) raises StopIteration -> ControlFlow[Int, Int]:
    raise StopIteration()

def callback_empty(var acc: Int, var item: Int) raises EmptyReductionError -> Int:
    raise EmptyReductionError()

def pure_step(var acc: Int, var item: Int) -> Int:
    return acc + item

def pure_control(var acc: Int, var item: Int) -> ControlFlow[Int, Int]:
    return ControlFlow[Int, Int](Continue(acc + item))

# Native compile-time checks: initialized pure calls introduce no raising channel.
def pure() -> Int:
    var a = List[Int]()
    var b = List[Int]()
    var c = fold_until(pure_control, 5, iter(b^))
    return reduce(pure_step, iter(a^), initial=2) + c^.unwrap[Continue[Int]]().into_payload()

def main() raises:
    assert_equal(pure(), 7)
    for mode in range(3):
        for length in range(5):
            for fail_at in range(6):
                for stop_at in range(6):
                    var native_pulls = ArcPointer(0)
                    var library_pulls = ArcPointer(0)
                    var native_trace = ArcPointer(List[Int]())
                    var library_trace = ArcPointer(List[Int]())
                    var native = exercise(False, mode, length, fail_at, stop_at, native_pulls, native_trace)
                    var actual = exercise(True, mode, length, fail_at, stop_at, library_pulls, library_trace)
                    assert_equal(actual, native)
                    assert_equal(library_pulls[], native_pulls[])
                    assert_equal(library_trace[], native_trace[])
    for mode in range(3):
        var pulls = ArcPointer(0)
        var failed = False
        if mode == 1:
            try:
                _ = reduce(stop, Source(4, pulls))
            except error:
                comptime assert type_of(error) == ReductionError[StopIteration]
                assert_true(error.isa[ReductionStepError[StopIteration]]())
                failed = True
        else:
            try:
                if mode == 0:
                    _ = reduce(stop, Source(4, pulls), initial=0)
                else:
                    _ = fold_until(stop_control, 0, Source(4, pulls))
            except error:
                comptime assert type_of(error) == StopIteration
                failed = True
        assert_true(failed)
        assert_equal(pulls[], 2 if mode == 1 else 1)
    for length in range(3):
        var pulls = ArcPointer(0)
        var outcome = 0
        var value = 0
        try:
            value = reduce(callback_empty, Source(length, pulls))
        except error:
            outcome = 1 if error.isa[EmptyReductionError]() else 2
            assert_equal(error.isa[ReductionStepError[EmptyReductionError]](), length == 2)
        if length == 1:
            assert_equal(value, 1)
        assert_equal(outcome, 1 if length == 0 else 0 if length == 1 else 2)
