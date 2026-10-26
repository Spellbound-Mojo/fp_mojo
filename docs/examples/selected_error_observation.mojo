"""Observe selected failures while preserving deferred and accumulating policy."""
from fp.algebra import ValidationFamily, ListMonoid
from fp.data import Result, Err
from fp.effects import Reader, ResultT, run
from fp.functions import pipeline


def fallback(var error: String) -> Int:
    return 12


def double(var value: Int) -> Int:
    return value * 2


def validation_audit(errors: List[String]) -> Result[NoneType,List[String]]:
    return Err(List[String](["audit"]))


def main() raises:
    comptime Environment = Reader[Int]
    comptime Deferred = ResultT[Environment,String]
    var observations = List[String]()
    def record(error: String) {ref observations} -> Result[NoneType,String]:
        observations.append(error)
        return Err(String("discarded observer result"))
    var pending = pipeline[Deferred](Deferred.fail[Int](String("missing"))).tap_err(record).recover(fallback).map(double).get()
    print("before run:", len(observations))
    var recovered = run[Environment](pending^,0)
    print("deferred:", recovered._ok().value, "; observed:", len(observations))

    def audit(error: String) -> Deferred.Failed[NoneType]:
        return Deferred.fail[NoneType](String("audit"))
    var audited = pipeline[Deferred](Deferred.fail[Int](String("original"))).flat_tap_err(audit).get()
    print("Result observer:", run[Environment](audited^,0)._err().value)

    comptime Validation = ValidationFamily[ListMonoid[String]]
    var accumulated = pipeline[Validation](Validation.fail[Int](List[String](["original"]))).flat_tap_err(validation_audit).get()
    ref errors = accumulated._err().value
    print("Validation observer:", errors[0], errors[1])
