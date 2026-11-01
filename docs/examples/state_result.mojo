"""Transformer order decides whether a stored failure returns the updated state."""
from fp.algebra import ResultFamily, fail
from fp.effects import State, StateT, ResultT, run, lift, put
from fp.functions import pipeline
from fp.data import Result
from std.testing import assert_equal

comptime DomainResult = Result[Int, String]
comptime Keep = ResultT[State[Int], String]
comptime Discard = StateT[ResultFamily[String], Int]


def main() raises:
    var preserving = (
        pipeline[Keep](lift[Keep](put[State[Int]](15)))
        .product_r(fail[Keep, Int](String("rejected")))
        .get()
    )
    var kept = run[State[Int]](preserving^, 10)
    comptime assert type_of(kept) == Tuple[DomainResult, Int]
    assert_equal(kept[0].is_err(), True)
    assert_equal(kept[1], 15)
    print("ResultT[State]: failed, returned state =", kept[1])

    var discarded = (
        pipeline(put[Discard](15))
        .product_r(fail[Discard, Int](String("rejected")))
        .run(10)
    )
    comptime assert type_of(discarded) == Result[Tuple[Int, Int], String]
    assert_equal(discarded.is_err(), True)
    print("StateT[Result]: failed, no state payload")
