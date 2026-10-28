"""Absence fallback preserves base failures, state and lazy factory timing."""
from fp.algebra import IdentityFamily, ResultFamily, ListFamily, or_else_absent, get_or_else_effect
from fp.effects import State, run
from fp.data import Result, Ok, Err
from std.testing import assert_equal, assert_true

def absent_backup() -> Optional[Int]: return Optional(9)
def value_backup() -> Int: return 7

def main() raises:
    assert_equal(or_else_absent[IdentityFamily](absent_backup, Optional(3)).value(), 3)
    assert_equal(or_else_absent[IdentityFamily](absent_backup, Optional[Int]()).value(), 9)
    assert_equal(get_or_else_effect[IdentityFamily](value_backup, Optional[Int]()), 7)
    var calls = 0
    def backup() {mut calls} -> Result[Optional[Int], String]:
        calls += 1
        return Ok(Optional(11))
    var failed = or_else_absent[ResultFamily[String]](backup, Result[Optional[Int], String](Err(String("bad"))))
    assert_true(failed.is_err())
    assert_equal(calls, 0)
    def state_backup() -> State[Int].Pure[Int]:
        return State[Int].pure(5)
    var program = get_or_else_effect[State[Int]](state_backup, State[Int].pure(Optional[Int]()))
    assert_equal(run[State[Int]](program^, 10), (5, 10))
    def branch_backup() -> List[Optional[Int]]:
        return [Optional(4), Optional(5)]
    var branches: List[Optional[Int]] = [Optional(1), None, Optional(3)]
    var result = or_else_absent[ListFamily](branch_backup, branches^)
    assert_equal(len(result), 4)
    assert_equal(result[0].value(), 1)
    assert_equal(result[1].value(), 4)
    assert_equal(result[2].value(), 5)
    assert_equal(result[3].value(), 3)
