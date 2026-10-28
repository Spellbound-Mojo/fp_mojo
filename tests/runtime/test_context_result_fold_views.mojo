"""Shared chains and native handlers mix without callable annotations."""
from fp.data import ok, err
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from std.testing import assert_equal


def add_one(var value: Int) -> Int: return value + 1
def show(var value: Int) -> String: return String(value)
def explain(var value: String) -> String: return "error " + value


def main() raises:
    var successes = 0
    def counted(var value: Int) {mut successes} -> Int:
        successes += 1
        return value
    var on_ok = kleisli[IdentityFamily](counted).map(add_one).map(show)
    var on_err = kleisli[IdentityFamily](explain)
    assert_equal(pipeline(ok[String](2)).fold_owned(on_ok, on_err), "3")
    assert_equal(pipeline(err[Int](String("bad"))).fold_owned(on_ok, on_err), "error bad")
    assert_equal(pipeline(ok[String](4)).fold_owned(on_ok, explain), "5")
    assert_equal(pipeline(err[Int](String("again"))).fold_owned(show, on_err), "error again")
    assert_equal(pipeline(ok[String](7)).fold_owned(on_ok^, on_err^), "8")
    assert_equal(successes, 3)
