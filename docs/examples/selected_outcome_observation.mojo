"""Observe success or failure without leaving a deferred selected family."""
from fp.data import Result
from fp.effects import Reader, ResultT, run
from fp.functions import pipeline


def missing(error: String) -> Bool:
    return error == "missing"


def fallback(var error: String) -> Int:
    return 5


def double(var value: Int) -> Int:
    return value * 2


def main() raises:
    comptime Environment = Reader[Int]
    comptime Deferred = ResultT[Environment, String]
    var observed = 0
    def audit(outcome: Result[Int, String]) {mut observed} -> Deferred.Pure[NoneType]:
        observed += 1
        if outcome.is_err() and outcome._err().value == "fatal":
            return Deferred.fail[NoneType](String("audit failed"))
        return Deferred.pure(NoneType())

    var pending = pipeline[Deferred](Deferred.fail[Int](String("missing"))).attempt_tap(audit).recover_if(missing, fallback).map(double).get()
    print("before run:", observed)
    print("recovered:", run[Environment](pending^, 0)._ok().value, "; observed:", observed)

    var accepted = pipeline[Deferred](Deferred.pure(3)).attempt_tap(audit).map(double).get()
    print("accepted:", run[Environment](accepted^, 0)._ok().value, "; observed:", observed)

    var failed = pipeline[Deferred](Deferred.fail[Int](String("fatal"))).attempt_tap(audit).get()
    print("observer failure:", run[Environment](failed^, 0)._err().value)
