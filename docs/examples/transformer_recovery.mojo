"""Transformer order determines which state recovery receives."""
from fp.algebra import ResultFamily, fail
from fp.effects import State, StateT, ResultT, put, lift, run
from fp.functions import pipeline, pipe, tupled
from fp.data import Result
from std.testing import assert_equal

comptime Restart = StateT[ResultFamily[String], Int]
comptime Keep = ResultT[State[Int], String]


def fallback(var message: String) -> Int:
    return 0


def show_kept(var outcome: Result[Int, String], state: Int) raises:
    var value = outcome^.raise_on_err()
    assert_equal(value, 0)
    assert_equal(state, 15)
    print("ResultT[State]: recovered value =", value, "; state =", state)


def main() raises:
    var restarted = (
        pipeline(put[Restart](15))
        .product_r(fail[Restart, Int](String("rejected")))
        .recover(fallback)
        .run(10)
    )
    var first = restarted^.raise_on_err()
    assert_equal(first, (0, 10))
    print("StateT[Result]: recovered value =", first[0], "; state =", first[1])

    var kept = (
        pipeline[Keep](lift[Keep](put[State[Int]](15)))
        .product_r(fail[Keep, Int](String("rejected")))
        .recover(fallback)
        .get()
    )
    pipe(run[State[Int]](kept^, 10), tupled(show_kept))
