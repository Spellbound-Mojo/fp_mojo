"""Native fold error channels, exact pulls, and empty/singleton boundaries."""
from fp.iteration import find, any, all
from fp.iteration import fold_left, reduce_optional, reduce, fold_until, ReductionError, ReductionStepError, EmptyReductionError
from fp.data import ControlFlow, Continue, Break
from std.iter import Iterator
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

def reduce_initial_pure1[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> A](f: F, var initial: A, var source: I) -> A where I.Element == T:
    return reduce(f, source^, initial=initial^)

def reduce_initial_pure2[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> A](f: F, var initial: A, var source: I) -> A where I.Element == T:
    return reduce_initial_pure1(f, initial^, source^)

def fold_until_pure1[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> ControlFlow[B, A]](f: F, var initial: A, var source: I) -> ControlFlow[B, A] where I.Element == T:
    return fold_until(f, initial^, source^)

def fold_until_pure2[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, //, F: def(var A, var T) -> ControlFlow[B, A]](f: F, var initial: A, var source: I) -> ControlFlow[B, A] where I.Element == T:
    return fold_until_pure1(f, initial^, source^)

def fold_left_error1[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](f: F, var initial: A, var source: I) raises E -> A where I.Element == T:
    return fold_left[E=E](f, initial^, source^)

def fold_left_error2[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](f: F, var initial: A, var source: I) raises E -> A where I.Element == T:
    return fold_left_error1[E=E](f, initial^, source^)

def reduce_initial_error1[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](f: F, var initial: A, var source: I) raises E -> A where I.Element == T:
    return reduce[E=E](f, source^, initial=initial^)

def reduce_initial_error2[A: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> A](f: F, var initial: A, var source: I) raises E -> A where I.Element == T:
    return reduce_initial_error1[E=E](f, initial^, source^)

def reduce_optional_error1[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var T, var T) raises E -> T](f: F, var source: I) raises E -> Optional[T] where I.Element == T:
    return reduce_optional[E=E](f, source^)

def reduce_optional_error2[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var T, var T) raises E -> T](f: F, var source: I) raises E -> Optional[T] where I.Element == T:
    return reduce_optional_error1[E=E](f, source^)

def reduce_error1[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var T, var T) raises E -> T](f: F, var source: I) raises ReductionError[E] -> T where I.Element == T:
    return reduce[E=E](f, source^)

def reduce_error2[T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var T, var T) raises E -> T](f: F, var source: I) raises ReductionError[E] -> T where I.Element == T:
    return reduce_error1[E=E](f, source^)

def fold_until_error1[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> ControlFlow[B, A]](f: F, var initial: A, var source: I) raises E -> ControlFlow[B, A] where I.Element == T:
    return fold_until[E=E](f, initial^, source^)

def fold_until_error2[A: Movable & Deinitable, B: Movable & Deinitable, T: Movable & Deinitable, I: Iterator, E: Movable & Deinitable, //, F: def(var A, var T) raises E -> ControlFlow[B, A]](f: F, var initial: A, var source: I) raises E -> ControlFlow[B, A] where I.Element == T:
    return fold_until_error1[E=E](f, initial^, source^)

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
struct TerminalFailure(Copyable, Writable):
    var code: Int

@fieldwise_init
struct Halt(Copyable):
    var item: Int

def exercise(library: Bool, mode: Int, length: Int, fail_at: Int, stop_at: Int,
             pulls: ArcPointer[Int], trace: ArcPointer[List[Int]]) -> Int:
    def step(var acc: Int, var item: Int) raises TerminalFailure {fail_at, trace} -> Int:
        trace[].append(100 * acc + item)
        if item == fail_at:
            raise TerminalFailure(item)
        return acc - item
    def control(var acc: Int, var item: Int) raises TerminalFailure {fail_at, stop_at, trace} -> ControlFlow[Halt, Int]:
        trace[].append(100 * acc + item)
        if item == fail_at:
            raise TerminalFailure(item)
        if item == stop_at:
            return ControlFlow[Halt, Int](Break(Halt(item)))
        return ControlFlow[Halt, Int](Continue(acc - item))
    var source = Source(length, pulls)
    if library and mode == 1:
        try:
            return reduce_error2(step, source^)
        except error:
            if error.isa[EmptyReductionError]():
                return -900
            return -1000 - error^.unwrap[ReductionStepError[TerminalFailure]]().into_error().code
    try:
        if library and mode == 0:
            return reduce_initial_error2(step, 20, source^)
        if library and mode == 3:
            return fold_left_error2(step, 20, source^)
        if library and mode == 4:
            var optional = reduce_optional_error2(step, source^)
            return optional.take() if optional else -900
        if library:
            var result = fold_until_error2(control, 20, source^)
            if result.isa[Break[Halt]]():
                return 2000 + result^.unwrap[Break[Halt]]().into_payload().item
            return result^.unwrap[Continue[Int]]().into_payload()
        var acc = 20
        if mode == 1 or mode == 4:
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
    var c = fold_until_pure2(pure_control, 5, iter(b^))
    return reduce_initial_pure2(pure_step, 2, iter(a^)) + c^.unwrap[Continue[Int]]().into_payload()

def main() raises:
    assert_equal(pure(), 7)
    for mode in range(5):
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
        if mode == 1 or mode == 4:
            try:
                _ = reduce_error2(stop, Source(4, pulls))
            except error:
                comptime assert type_of(error) == ReductionError[StopIteration]
                assert_true(error.isa[ReductionStepError[StopIteration]]())
                failed = True
        else:
            try:
                if mode == 0:
                    _ = reduce_initial_error2(stop, 0, Source(4, pulls))
                else:
                    _ = fold_until_error2(stop_control, 0, Source(4, pulls))
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
            value = reduce_error2(callback_empty, Source(length, pulls))
        except error:
            outcome = 1 if error.isa[EmptyReductionError]() else 2
            assert_equal(error.isa[ReductionStepError[EmptyReductionError]](), length == 2)
        if length == 1:
            assert_equal(value, 1)
        assert_equal(outcome, 1 if length == 0 else 0 if length == 1 else 2)
