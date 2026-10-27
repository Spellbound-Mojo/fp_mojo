"""Errors stay exact; deferred callbacks and combinations run only with the effect."""
from fp.functions import pipeline
from fp.algebra import Monoid
from fp.effects import Reader, State, action, run
from fp.callables import Unary
from std.memory import ArcPointer
from std.testing import assert_equal
from algebra_support.iterators import Counted

@fieldwise_init
struct QueryFailure(Movable):
    var code: Int

struct QueryMonoid[fail_start: Bool](Monoid):
    comptime Value = String
    comptime Error = QueryFailure
    @staticmethod
    def empty() raises Self.Error -> String:
        if Self.fail_start: raise QueryFailure(10)
        return String()
    @staticmethod
    def combine(var a: String, var b: String) raises Self.Error -> String:
        if b == "2": raise QueryFailure(20)
        a += b
        return a^

@fieldwise_init
struct StatePredicate(Unary):
    var value: Int
    comptime Arg = Int
    comptime Out = Tuple[Bool, Int]
    def call(self, var state: Int) -> Self.Out: return (self.value == 2, state + 1)

def state_predicate(value: Int) -> State[Int].Endpoint[Bool, StatePredicate]:
    return action[State[Int], Bool](StatePredicate(value))

def main() raises:
    var calls = ArcPointer(0)
    var pulls = 0
    var code = 0
    def text(var value: Int) {calls} -> Optional[String]:
        calls[] += 1
        return Optional(String(value))
    try: _ = pipeline(Counted(Pointer(to=pulls),0,5)).fold_map_effect[QueryMonoid[True]](text).get()
    except error:
        comptime assert type_of(error) == QueryFailure
        code = error.code
    assert_equal(code, 10); assert_equal(calls[], 0); assert_equal(pulls, 0)
    try: _ = pipeline(Counted(Pointer(to=pulls),0,5)).fold_map_effect[QueryMonoid[False]](text).get()
    except error: code = error.code
    assert_equal(code, 20); assert_equal(calls[], 2); assert_equal(pulls, 2)
    def stop(value: Int) raises StopIteration -> Optional[Bool]: raise StopIteration()
    var stopped = False
    try: _ = pipeline(range(4)).raising[StopIteration]().find_effect(stop).get()
    except StopIteration: stopped = True
    assert_equal(stopped, True)

    comptime Deferred = Reader[Int]
    calls[] = 0; pulls = 0
    def select(var value: Int) {calls} -> Deferred.Pure[Optional[Int]]:
        calls[] += 1
        return Deferred.pure(Optional(value) if value == 2 else Optional[Int]())
    var pending = pipeline(Counted(Pointer(to=pulls),0,5)).find_map_effect[Deferred](select).get()
    assert_equal(calls[], 0); assert_equal(pulls, 0)
    assert_equal(run[Deferred](pending^, 10).value(), 2)
    assert_equal(calls[], 2); assert_equal(pulls, 2)
    calls[] = 0; pulls = 0
    def fail(var value: Int) raises QueryFailure {calls} -> Deferred.Pure[Optional[Int]]:
        calls[] += 1
        raise QueryFailure(value)
    var failed = pipeline(Counted(Pointer(to=pulls),0,5)).raising[QueryFailure]().find_map_effect[Deferred](fail).get()
    assert_equal(calls[], 0); assert_equal(pulls, 0)
    try: _ = run[Deferred](failed^, 0)
    except error:
        comptime assert type_of(error) == QueryFailure
        code = error.code
    assert_equal(code, 1); assert_equal(calls[], 1); assert_equal(pulls, 1)
    calls[] = 0; pulls = 0
    def later(var value: Int) {calls} -> Deferred.Pure[String]:
        calls[] += 1
        return Deferred.pure(String(value))
    try: _ = pipeline(Counted(Pointer(to=pulls),0,5)).fold_map_effect[Deferred, QueryMonoid[True]](later).get()
    except error: code = error.code
    assert_equal(code, 10); assert_equal(calls[], 0); assert_equal(pulls, 0)
    try:
        var combined = pipeline(Counted(Pointer(to=pulls),0,5)).fold_map_effect[Deferred, QueryMonoid[False]](later).get()
        if calls[] != 0 or pulls != 0: raise QueryFailure(-1)
        _ = run[Deferred](combined^, 0)
    except error: code = error.code
    assert_equal(code, 20); assert_equal(calls[], 2); assert_equal(pulls, 2)
    pulls = 0
    var selected = pipeline(Counted(Pointer(to=pulls),0,5)).find_effect[State[Int]](state_predicate).get()
    assert_equal(pulls, 0)
    var output = run[State[Int]](selected^, 10)
    assert_equal(output[0].value(), 2); assert_equal(output[1], 12); assert_equal(pulls, 2)
