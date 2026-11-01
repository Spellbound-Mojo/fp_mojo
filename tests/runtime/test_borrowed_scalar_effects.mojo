"""Borrowing predicates must observe consumed scalar values at O0 and O3."""
from fp.algebra import ResultFamily
from fp.callables import BorrowCallable
from fp.data import Result, Ok
from fp.functions import pipeline
from fp.iteration import any_effect, all_effect, iterated
from std.testing import assert_true, assert_false


def scalar_effect_large(value: Int) -> Result[Bool, String]:
    return Ok(value > 5)


@fieldwise_init
struct ScalarEffectPositive(BorrowCallable):
    comptime Payload = Int
    comptime Result = Result[Bool, String]
    def invoke(self, ref payload: Int) raises Never capturing -> Self.Result:
        return Ok(payload > 0)


def main() raises:
    # Both native callbacks and library BorrowCallable values reach the shared
    # borrowing bridge from a consumed scalar in the effectful fold step.
    var values: List[Int] = [3, 5, 8]
    assert_true(any_effect[ResultFamily[String]](values.copy(), scalar_effect_large).raise_on_err())
    assert_false(all_effect[ResultFamily[String]](values.copy(), scalar_effect_large).raise_on_err())
    assert_true(iterated(values.copy()).all_effect[ResultFamily[String]](ScalarEffectPositive()).raise_on_err())
    assert_true(pipeline(values^).any_effect[ResultFamily[String]](ScalarEffectPositive()).get().raise_on_err())
    var negatives: List[Int] = [-3, -5, -8]
    assert_false(any_effect[ResultFamily[String]](negatives^, ScalarEffectPositive()).raise_on_err())
    assert_false(any_effect[ResultFamily[String]](List[Int](), scalar_effect_large).raise_on_err())
    assert_true(all_effect[ResultFamily[String]](List[Int](), ScalarEffectPositive()).raise_on_err())
