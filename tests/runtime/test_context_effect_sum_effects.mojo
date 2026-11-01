"""Exact native errors and deferred execution share the existing fold contract."""
from fp.functions import pipeline
from fp.data import Result, Err
from fp.effects import Reader, run
from std.testing import assert_equal
from algebra_support.iterators import Counted

@fieldwise_init
struct SumFailure(Movable):
    var code: Int

def forwarded[A: Movable & Deinitable, E: Movable & Deinitable, dtype: DType, size: SIMDLength, //,
              F: def(var A) raises E -> Optional[SIMD[dtype, size]]](ref function: F, var source: List[A]) raises E -> Optional[SIMD[dtype, size]] where dtype.is_integral() or dtype.is_floating_point():
    return pipeline(source^).raising[E]().sum_by_effect(function).get()

def origins(owner: List[Int], errors: List[Int]) raises:
    comptime View = type_of(Span(owner))
    comptime Failure = type_of(Span(errors))
    var failure = Span(errors)
    def length(var value: View) -> Optional[Int]: return Optional(len(value))
    assert_equal(forwarded(length, List[View]([Span(owner)])).value(), len(owner))
    def reject(var value: View) {failure} -> Result[Int, Failure]: return Err(failure)
    var result = pipeline(List[View]([Span(owner)])).sum_by_effect(reject).get()
    assert_equal(result._err().value.unsafe_ptr() == Span(errors).unsafe_ptr(), True)
    def fail(var value: View) raises Failure {failure} -> Optional[Float64]: raise failure
    var matched = False
    try: _ = forwarded(fail, List[View]([Span(owner)]))
    except error: matched = error.unsafe_ptr() == Span(errors).unsafe_ptr()
    assert_equal(matched, True)

def main() raises:
    var calls = 0
    var pulls = 0
    var code = 0
    def fail(var x: Int) raises SumFailure {mut calls} -> Optional[Int]:
        calls += 1
        raise SumFailure(x)
    try: _ = pipeline(Counted(Pointer(to=pulls), 0, 4)).raising[SumFailure]().sum_by_effect(fail).get()
    except error:
        comptime assert type_of(error) == SumFailure
        code = error.code
    assert_equal(code, 1); assert_equal(pulls, 1); assert_equal(calls, 1)
    comptime Deferred = Reader[Int]
    calls = 0; pulls = 0
    def later(var x: Int) {mut calls} -> Deferred.Pure[Float64]:
        calls += 1
        return Deferred.pure(Float64(x))
    var pending = pipeline(Counted(Pointer(to=pulls), 0, 3)).sum_by_effect[Deferred](later).get()
    assert_equal(calls, 0); assert_equal(pulls, 0)
    assert_equal(run[Deferred](pending^, 0), 6.0)
    assert_equal(calls, 3); assert_equal(pulls, 4)
    var values = List[Deferred.Pure[Float64]]()
    values.append(Deferred.pure(Float64(2))); values.append(Deferred.pure(Float64(3)))
    var summed = pipeline(values^).sum_effect[Deferred]().get()
    assert_equal(run[Deferred](summed^, 0), 5.0)
    calls = 0; pulls = 0
    def delayed_failure(var x: Int) raises SumFailure {mut calls} -> Deferred.Pure[Int]:
        calls += 1
        raise SumFailure(x)
    var failed = pipeline(Counted(Pointer(to=pulls), 0, 3)).raising[SumFailure]().sum_by_effect[Deferred](delayed_failure).get()
    assert_equal(calls, 0); assert_equal(pulls, 0)
    try: _ = run[Deferred](failed^, 0)
    except error: code = error.code
    assert_equal(code, 1); assert_equal(calls, 1); assert_equal(pulls, 1)
    origins(List[Int]([1, 2]), List[Int]([3, 4]))
