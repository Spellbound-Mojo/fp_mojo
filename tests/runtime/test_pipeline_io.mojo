"""Fluent IO preserves entered-scope cleanup, cancellation and ordered failures."""
from fp.functions import pipeline, Pipeline
from fp.algebra import Functor
from fp.effects import IOContract, ReaderAction, Outcome, EffectFailure, CancellationToken, delay, canceled
from fp.callables import OnceThunk
from std.memory import ArcPointer
from std.testing import assert_equal, assert_true

@fieldwise_init
struct Step(OnceThunk):
    var log: ArcPointer[List[Int]]
    var token: CancellationToken
    var code: Int
    var cancel: Bool
    var fail: Bool
    comptime Out = Int
    comptime Error = Int
    def call_once(deinit self) raises Int -> Int:
        self.log[].append(self.code)
        if self.cancel: self.token.cancel()
        if self.fail: raise self.code
        return self.code

def failure[T: Movable & Deinitable](var outcome: Outcome[T, Int]) raises -> EffectFailure[Int]:
    assert_true(Bool(outcome))
    var result = outcome.take()
    assert_true(result.is_err())
    try:
        return result^.swap().raise_on_err()
    except:
        raise Error("expected a failure outcome")

def execute[I: Functor, P: ReaderAction](var program: Pipeline[I, P]) -> IOContract[P].Out where I == P.Family and IOContract[P].Compatible:
    return program^.run_io()

def protect[I: Functor, P: ReaderAction, Q: ReaderAction](var program: Pipeline[I, P], var finalizer: Q) -> IOContract[P].Out where I == P.Family and IOContract[P].Compatible and IOContract[Q].Compatible and IOContract[P].Error == IOContract[Q].Error:
    return program^.guarantee(finalizer^).run_io()

def exercise[only_cancel: Bool]() raises:
    for cancel in range(2):
        for fail in range(2):
            for cleanup_fail in range(2):
                var log = ArcPointer(List[Int]())
                var token = CancellationToken()
                var body = delay[Int](Step(log, token.copy(), 1, Bool(cancel), Bool(fail)))
                var cleanup = delay[Int](Step(log, token.copy(), 2, False, Bool(cleanup_fail)))
                assert_equal(log[], List[Int]())
                var result: Outcome[Int, Int]
                comptime if only_cancel:
                    result = pipeline(body^).on_cancel(cleanup^).run_io(token)
                else:
                    result = pipeline(body^).guarantee(cleanup^).run_io(token)
                var entered_cleanup = not only_cancel or Bool(cancel)
                var expected_log: List[Int] = [1]
                if entered_cleanup: expected_log.append(2)
                assert_equal(log[], expected_log)
                if fail or (cleanup_fail and entered_cleanup):
                    var failed = failure(result^)
                    assert_equal(failed.canceled, Bool(cancel))
                    var expected = List[Int]()
                    if fail: expected.append(1)
                    if cleanup_fail and entered_cleanup: expected.append(2)
                    assert_equal(failed^.into_errors().into_list(), expected)
                elif cancel:
                    assert_true(not result)
                else:
                    assert_equal(result.take().get_or(0), 1)


def body() -> Int: return 21
def twice(var value: Int) -> Int: return value * 2
def finish(): pass

def external(owner: List[Int]) raises -> Span[Int, origin_of(owner)]:
    def view() {imm owner} -> Span[Int, origin_of(owner)]: return Span(owner)
    var outcome = pipeline(delay[Never](view)).run_io()
    assert_true(Bool(outcome))
    var result = outcome.take()
    assert_true(result.is_ok())
    return result^.get_or(Span(owner))

def main() raises:
    exercise[False]()
    exercise[True]()
    var ordinary = execute(pipeline(delay[Int](body)).map(twice))
    assert_equal(ordinary.take().get_or(0), 42)
    var protected = protect(pipeline(delay[Int](body)), delay[Int](finish))
    assert_equal(protected.take().get_or(0), 21)
    var log = ArcPointer(List[Int]())
    var token = CancellationToken()
    var nested = pipeline(delay[Int](Step(log, token.copy(), 1, False, True))).guarantee(delay[Int](Step(log, token.copy(), 2, False, True))).guarantee(delay[Int](Step(log, token.copy(), 3, False, True)))
    assert_equal(log[], List[Int]())
    var failed = failure(nested^.run_io(token))
    assert_equal(log[], [1, 2, 3])
    assert_equal(failed^.into_errors().into_list(), [1, 2, 3])
    log[] = List[Int]()
    token.cancel()
    var unopened = pipeline(delay[Int](Step(log, token.copy(), 1, False, False))).guarantee(delay[Int](Step(log, token.copy(), 2, False, False))).run_io(token)
    assert_true(not unopened)
    assert_true(token.requested())
    assert_equal(log[], List[Int]())
    var cancellation = pipeline(canceled[Int]()).on_cancel(delay[Int](finish)).run_io()
    assert_true(not cancellation)
    var owner: List[Int] = [7, 11]
    var view = external(owner)
    assert_true(Pointer(to=view[0]) == Pointer(to=owner[0]))
