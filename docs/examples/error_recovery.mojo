from fp.algebra import IdentityFamily, ListFamily, ListMonoid, ResultFamily, ValidationFamily, fail
from fp.data import Result, Ok, Err
from fp.effects import ResultT
from fp.functions import pipeline, kleisli


def fallback(var message: String) -> Int:
    return 0


def retry(var message: String) -> Result[Int, String]:
    return Ok(42)


def is_missing(message: String) -> Bool:
    return message == "missing"


def recovery_observer(error: String) -> Result[NoneType, String]:
    return Err(String("observer failed"))


def recovery_validation_observer(errors: List[String]) -> Result[NoneType, List[String]]:
    return Err(List[String](["observer failed"]))


def main():
    comptime Errors = ResultFamily[String]
    var restore = kleisli[IdentityFamily](fallback)
    var retrying = kleisli[Errors](retry)
    var recovered = pipeline(fail[Errors, Int](String("missing"))).or_else(retrying).get()
    print("retried:", recovered._ok().value)

    var entries: List[Result[Int, String]] = [
        Result[Int, String](Ok(3)),
        Result[Int, String](Err(String("missing"))),
        Result[Int, String](Ok(5)),
    ]
    var values = pipeline[ResultT[ListFamily, String]](entries^).recover(restore).get()
    print("entries:", values[0]._ok().value, values[1]._ok().value, values[2]._ok().value)

    comptime Nested = ResultT[Errors, String]
    var outer = Result[Result[Int, String], String](Err(String("connection failed")))
    var untouched = pipeline[Nested](outer^).recover(restore).get()
    print("outer:", untouched._err().value)

    var failures: List[Result[Int, String]] = [
        Result[Int, String](Err(String("missing"))),
        Result[Int, String](Err(String("denied"))),
    ]
    var selective = pipeline[ResultT[ListFamily, String]](failures^).recover_if(is_missing, fallback).get()
    print("selected:", selective[0]._ok().value, "; kept:", selective[1]._err().value)
    var retried = pipeline(fail[Errors, Int](String("missing"))).or_else_if(is_missing, retry).get()
    print("selected retry:", retried._ok().value)

    var inspected = pipeline(fail[Errors, Int](String("original"))).tap_err(recovery_observer).get()
    print("inspection kept:", inspected._err().value)
    var observed = pipeline(fail[Errors, Int](String("original"))).flat_tap_err(recovery_observer).get()
    print("Result observer:", observed._err().value)

    comptime Validation = ValidationFamily[ListMonoid[String]]
    var accumulated = pipeline[Validation](fail[Validation, Int](List[String](["original"]))).flat_tap_err(recovery_validation_observer).get()
    print("Validation observer:", accumulated._err().value)
