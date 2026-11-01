"""Whole-value transitions preserve the selected error and exact native values."""
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from fp.algebra import ListFamily, OptionalFamily, ResultFamily, IdentityFamily
from fp.effects import ReaderT, run
from fp.callables import OnceUnary
from std.testing import assert_equal

@fieldwise_init
struct ContextStagesFault(Movable):
    var code: Int
@fieldwise_init
struct ContextStagesOnce(OnceUnary):
    var amount: Int
    comptime Arg = Int
    comptime Out = Int
    comptime Error = Never
    def call_once(deinit self, var value: Int) -> Int: return value + self.amount

def values(var x: Int) -> List[Int]: return List[Int]([x, x + 1])
def count(var xs: List[Int]) -> Int: return len(xs)
def inc(var x: Int) -> Int: return x + 1
def never_inc(var x: Int) raises Never -> Int: return x + 1
def optional(var x: Int) -> Optional[Int]: return Optional(x)
def checked(var x: Int) -> Result[Int, String]: return Ok(x)
def reject(var x: Int) raises ContextStagesFault -> Int: raise ContextStagesFault(x)
def sum_pair(var a: Int, var b: Int) -> Int: return a + b

def forward[V: Movable & Deinitable, F: OnceUnary](var value: V, var stage: F) raises F.Error -> F.Out where F.Arg == V:
    return pipeline[IdentityFamily](value^).then(stage^).get()

def pure_chain() -> Int:
    return pipeline(2).raising[ContextStagesFault]().then(values).map(never_inc).fold_left(sum_pair, 0).then(ContextStagesOnce(4)).get()

def main() raises:
    assert_equal(pure_chain(), 11)
    assert_equal(forward(2, ContextStagesOnce(3)), 5)
    assert_equal(pipeline(3).then(values).then(count).then(optional).map(inc).then(checked_optional).get()._ok().value, 3)
    var delta = 4
    def captured(var x: Int) {delta} -> Int: return x + delta
    assert_equal(pipeline(2).then(captured).get(), 6)
    assert_equal(captured(3), 7)
    var code = 0
    try: _ = pipeline(8).raising[ContextStagesFault]().then(never_inc).then(reject).get()
    except error: code = error.code
    assert_equal(code, 9)
    # Whole-value stages can observe stored failure; they do not skip it.
    assert_equal(pipeline(Result[Int, String](Err(String("missing")))).then(observe).get(), -1)
    comptime Reader = ReaderT[OptionalFamily, Int]
    def defer(var value: Int) -> Reader.Pure[Int]: return Reader.pure(value)
    var calls = 0
    def delayed(var value: Int) {mut calls} -> Int:
        calls += 1
        return value + 2
    var pending = pipeline(7).then[Reader](defer).map(delayed).get()
    assert_equal(calls, 0)
    var done = run[Reader](pending^, 0)
    assert_equal(done.value(), 9)
    assert_equal(calls, 1)
    # Explicit Identity keeps a known native container as one payload.
    assert_equal(pipeline(3).then[IdentityFamily](values).map(count).get(), 2)

def checked_optional(var x: Optional[Int]) -> Result[Int, String]: return Ok(x.take())
def observe(var x: Result[Int, String]) -> Int: return -1 if x.is_err() else 1
