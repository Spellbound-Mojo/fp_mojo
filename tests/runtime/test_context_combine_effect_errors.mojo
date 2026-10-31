"""Monoid errors remain exact and deferred targets retain execution timing."""
from fp.functions import pipeline
from fp.algebra import Monoid, StringMonoid
from fp.callables import BorrowCallable
from fp.effects import Reader, action, run
from std.memory import ArcPointer
from std.testing import assert_equal
from test_context_combine_effect_behavior import TextEffects

struct CombiningFailure[fail_start: Bool](Monoid):
    comptime Value = String
    comptime Error = Int
    @staticmethod
    def empty() raises Int -> String:
        if Self.fail_start: raise 10
        return String()
    @staticmethod
    def combine(var left: String, var right: String) raises Int -> String:
        if right == "2": raise 20
        return left + right

@fieldwise_init
struct DeferredText(BorrowCallable):
    var text: String
    var calls: ArcPointer[Int]
    comptime Payload = Int
    comptime Result = String
    comptime Failure = Never
    def invoke(self, ref environment: Int) -> String:
        self.calls[] += 1
        return self.text

def actions(calls: ArcPointer[Int]) -> List[Reader[Int].Endpoint[String, DeferredText]]:
    var values = List[Reader[Int].Endpoint[String, DeferredText]]()
    values.append(action[Reader[Int], String](DeferredText(String("1"), calls)))
    values.append(action[Reader[Int], String](DeferredText(String("2"), calls)))
    values.append(action[Reader[Int], String](DeferredText(String("3"), calls)))
    return values^

def main() raises:
    var pulls = 0
    var code = 0
    # The selected native callback error does not reinterpret a monoid error.
    try: _ = pipeline(TextEffects(Pointer(to=pulls), 0, 4, 0)).raising[String]().combine_all_effect[CombiningFailure[True]]().get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 10); assert_equal(pulls, 0)
    try: _ = pipeline(TextEffects(Pointer(to=pulls), 0, 4, 0)).combine_all_effect[CombiningFailure[False]]().get()
    except error: code = error
    assert_equal(code, 20); assert_equal(pulls, 2)
    comptime Deferred = Reader[Int]
    var calls = ArcPointer(0)
    var pending = pipeline(actions(calls)).combine_all_effect[StringMonoid, Deferred]().get()
    assert_equal(calls[], 0)
    assert_equal(run[Deferred](pending^, 0), "123")
    assert_equal(calls[], 3)
    calls[] = 0
    try: _ = pipeline(actions(calls)).combine_all_effect[CombiningFailure[True], Deferred]().get()
    except error: code = error
    assert_equal(code, 10); assert_equal(calls[], 0)
    var before_run = -1
    try:
        var failed = pipeline(actions(calls)).combine_all_effect[CombiningFailure[False], Deferred]().get()
        before_run = calls[]
        _ = run[Deferred](failed^, 0)
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 20); assert_equal(calls[], 2); assert_equal(before_run, 0)
