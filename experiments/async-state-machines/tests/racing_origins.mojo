from fp.data import Left
from state_machine import pure, run
from foundation import race_first as race, timeout_after as timeout_to
from foundation import Borrowed, check

def exercise[o: ImmOrigin](ref[o] owner: List[Int]):
    var winner = run(race(Borrowed(Pointer(to=owner), 0, False), Borrowed(Pointer(to=owner), 0, False)))
    check(winner.take()._take_ok().unwrap[Left[Span[Int, o]]]().into_payload()[1] == 17, "race retains borrowed value origin")
    var failed = run(race(Borrowed(Pointer(to=owner), 0, True), Borrowed(Pointer(to=owner), 0, False)))
    check(failed.take()._take_err().errors.first()[0] == 13, "race retains borrowed error origin")
    var timeout = run(timeout_to(Borrowed(Pointer(to=owner), 0, False), 0, pure[Span[Int, o]](Span(owner))))
    check(timeout.take()._take_ok()[1] == 17, "timeout fallback retains external origin")

def main():
    var owner = List[Int]([13, 17])
    exercise(owner)
    print("racing origins: borrowed winners, errors, and fallback values")
