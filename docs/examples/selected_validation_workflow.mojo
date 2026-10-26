"""Validate, observe and recover inside one deferred selected family."""
from fp.effects import Reader, ResultT, run
from fp.functions import pipeline


def positive(value: Int) -> Bool:
    return value > 0


def invalid(value: Int) -> String:
    return String("nonpositive")


def recoverable(error: String) -> Bool:
    return error == "nonpositive"


def fallback(var error: String) -> Int:
    return 5


def double(var value: Int) -> Int:
    return value * 2


def main() raises:
    comptime Environment = Reader[Int]
    comptime Deferred = ResultT[Environment, String]
    var observed = 0
    def record(error: String) {mut observed}:
        observed += 1

    var pending = pipeline[Deferred](Deferred.pure(-2)).ensure(positive, invalid).tap_err(record).recover_if(recoverable, fallback).map(double).get()
    print("before run:", observed)
    print("recovered:", run[Environment](pending^, 0)._ok().value, "; observed:", observed)

    var accepted = pipeline[Deferred](Deferred.pure(3)).ensure(positive, invalid).tap_err(record).recover_if(recoverable, fallback).map(double).get()
    print("accepted:", run[Environment](accepted^, 0)._ok().value, "; observed:", observed)
