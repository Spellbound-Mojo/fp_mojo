"""Transformer order determines which state recovery receives."""
from fp.algebra import ResultFamily, fail
from fp.effects import State, StateT, ResultT, put, lift, run
from fp.functions import piped

comptime Restart = StateT[ResultFamily[String], Int]
comptime Keep = ResultT[State[Int], String]


def failure_restarting_state() -> Restart.Failed[Int]:
    return fail[Restart, Int](String("rejected"))


def failure_preserving_state() -> Keep.Failed[Int]:
    return fail[Keep, Int](String("rejected"))


def fallback(var message: String) -> Int:
    return 0


def main():
    var restarted = (
        piped(put[Restart](15))
        .followed_by[Restart](failure_restarting_state)
        .recover[Restart](fallback)
        .get()
    )
    var first = run[Restart](restarted^, 10)
    print("StateT[Result]: recovered value =", first._ok().value[0], "; state =", first._ok().value[1])

    var kept = (
        piped(lift[Keep](put[State[Int]](15)))
        .followed_by[Keep](failure_preserving_state)
        .recover[Keep](fallback)
        .get()
    )
    var second = run[State[Int]](kept^, 10)
    print("ResultT[State]: recovered value =", second[0]._ok().value, "; state =", second[1])
