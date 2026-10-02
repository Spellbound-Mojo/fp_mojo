"""Native cleanup of fold inputs, accumulators, callback state and typed errors."""
from fp.iteration import ReductionError, fold_left, reduce_optional, reduce, fold_until, EmptyReductionError, ReductionStepError
from fp.data import ControlFlow, Continue, Break
from std.iter import Iterator
from std.memory import ArcPointer
from std.testing import assert_equal

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
struct TerminalGenericFoldsToken(Movable):
    var value: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct FoldFailure(Movable):
    var code: Int
    var drops: ArcPointer[Int]
    def __deinit__(deinit self):
        self.drops[] += 1

@fieldwise_init
struct Source(Iterator):
    comptime Element = TerminalGenericFoldsToken
    var remaining: List[TerminalGenericFoldsToken]
    var state: TerminalGenericFoldsToken
    var trace: ArcPointer[List[Int]]
    def __next__(mut self) raises StopIteration -> TerminalGenericFoldsToken:
        self.state.value += 1
        self.trace[].append(self.state.value)
        if not self.remaining: raise StopIteration()
        return self.remaining.pop()

def exercise(library: Bool, mode: Int, length: Int, fail_at: Int, stop_at: Int,
             drops: ArcPointer[Int], errors: ArcPointer[Int], states: ArcPointer[Int],
             trace: ArcPointer[List[Int]]) -> Int:
    var remaining = List[TerminalGenericFoldsToken]()
    for i in range(length):
        remaining.append(TerminalGenericFoldsToken(length - i, drops))
    var source = Source(remaining^, TerminalGenericFoldsToken(0, states), trace)
    var seed = TerminalGenericFoldsToken(7, states)
    var state = TerminalGenericFoldsToken(0, states)
    def step(var acc: TerminalGenericFoldsToken, var item: TerminalGenericFoldsToken) raises FoldFailure {var seed^, mut state, trace, errors, fail_at} -> TerminalGenericFoldsToken:
        state.value += 1
        trace[].append(1000 * state.value + 10 * acc.value + item.value + seed.value)
        if item.value == fail_at: raise FoldFailure(item.value, errors)
        acc.value -= item.value
        return acc^
    var control_state = TerminalGenericFoldsToken(0, states)
    def control(var acc: TerminalGenericFoldsToken, var item: TerminalGenericFoldsToken) raises FoldFailure {mut control_state, trace, errors, fail_at, stop_at} -> ControlFlow[TerminalGenericFoldsToken, TerminalGenericFoldsToken]:
        control_state.value += 1
        trace[].append(1000 * control_state.value + 10 * acc.value + item.value)
        if item.value == fail_at: raise FoldFailure(item.value, errors)
        if item.value == stop_at: return ControlFlow[TerminalGenericFoldsToken, TerminalGenericFoldsToken](Break(acc^))
        acc.value -= item.value
        return ControlFlow[TerminalGenericFoldsToken, TerminalGenericFoldsToken](Continue(acc^))
    if library and mode == 1:
        try:
            var output = reduce_error2(step, source^)
            return output.value
        except error:
            if error.isa[EmptyReductionError](): return -900
            var failure = error^.unwrap[ReductionStepError[FoldFailure]]().into_error()
            return -1000 - failure.code
    try:
        if library and mode == 0:
            var output = reduce_initial_error2(step, TerminalGenericFoldsToken(20, drops), source^)
            return output.value
        if library and mode == 3:
            var output = fold_left_error2(step, TerminalGenericFoldsToken(20, drops), source^)
            return output.value
        if library and mode == 4:
            var optional = reduce_optional_error2(step, source^)
            return optional.value().value if optional else -900
        if library:
            var output = fold_until_error2(control, TerminalGenericFoldsToken(20, drops), source^)
            if output.isa[Break[TerminalGenericFoldsToken]]():
                return 2000 + output^.unwrap[Break[TerminalGenericFoldsToken]]().into_payload().value
            return output^.unwrap[Continue[TerminalGenericFoldsToken]]().into_payload().value
        var acc: TerminalGenericFoldsToken
        if mode == 1 or mode == 4:
            try: acc = source.__next__()
            except: return -900
        else:
            acc = TerminalGenericFoldsToken(20, drops)
        while True:
            var item: TerminalGenericFoldsToken
            try: item = source.__next__()
            except: return acc.value
            if mode == 2:
                var output = control(acc^, item^)
                if output.isa[Break[TerminalGenericFoldsToken]]():
                    return 2000 + output^.unwrap[Break[TerminalGenericFoldsToken]]().into_payload().value
                acc = output^.unwrap[Continue[TerminalGenericFoldsToken]]().into_payload()
            else:
                acc = step(acc^, item^)
    except error:
        return -1000 - error.code

def main() raises:
    for mode in range(5):
        for length in range(5):
            for fail_at in range(6):
                for stop_at in range(6):
                    var results = List[Int]()
                    var traces = List[List[Int]]()
                    var error_counts = List[Int]()
                    for library in range(2):
                        var drops = ArcPointer(0)
                        var errors = ArcPointer(0)
                        var states = ArcPointer(0)
                        var trace = ArcPointer(List[Int]())
                        results.append(exercise(Bool(library), mode, length, fail_at, stop_at, drops, errors, states, trace))
                        assert_equal(drops[], length + (0 if mode == 1 or mode == 4 else 1))
                        assert_equal(states[], 4)
                        error_counts.append(errors[])
                        traces.append(trace[].copy())
                    assert_equal(results[0], results[1])
                    assert_equal(error_counts[0], 1 if results[0] <= -1000 else 0)
                    assert_equal(error_counts[0], error_counts[1])
                    assert_equal(traces[0], traces[1])
