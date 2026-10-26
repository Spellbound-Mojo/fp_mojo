"""Recover matching stored errors without leaving the selected family."""
from fp.effects import Reader, ResultT, run
from fp.functions import pipeline


def missing(error: String) -> Bool:
    return error == "missing"


def double(var value: Int) -> Int:
    return value * 2


def main() raises:
    comptime Environment = Reader[Int]
    comptime Deferred = ResultT[Environment,String]
    var handled = 0
    def fallback(var error: String) {mut handled} -> Int:
        handled += 1
        return 7

    var pending = pipeline[Deferred](Deferred.fail[Int](String("missing"))).recover_if(missing,fallback).map(double).get()
    print("before run:", handled)
    print("recovered:", run[Environment](pending^,0)._ok().value)

    var untouched = pipeline[Deferred](Deferred.fail[Int](String("denied"))).recover_if(missing,fallback).get()
    print("preserved:", run[Environment](untouched^,0)._err().value, "; handled:", handled)

    def retry(var error: String) -> Deferred.Pure[Int]:
        return Deferred.pure(9)
    var retried = pipeline[Deferred](Deferred.fail[Int](String("missing"))).or_else_if(missing,retry).get()
    print("retried:", run[Environment](retried^,0)._ok().value)
