from fp.algebra import ListFamily, ListMonoid, ResultFamily, ValidationFamily, fail
from fp.data import Result, Ok, Err
from fp.effects import ResultT
from fp.functions import piped


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
    var recovered = piped(fail[Errors, Int](String("missing"))).or_else[Errors](retry).get()
    print("retried:", recovered._ok().value)

    var entries: List[Result[Int, String]] = [
        Result[Int, String](Ok(3)),
        Result[Int, String](Err(String("missing"))),
        Result[Int, String](Ok(5)),
    ]
    var values = piped(entries^).recover[ResultT[ListFamily, String]](fallback).get()
    print("entries:", values[0]._ok().value, values[1]._ok().value, values[2]._ok().value)

    comptime Nested = ResultT[Errors, String]
    var outer = Result[Result[Int, String], String](Err(String("connection failed")))
    var untouched = piped(outer^).recover[Nested](fallback).get()
    print("outer:", untouched._err().value)

    var failures: List[Result[Int, String]] = [
        Result[Int, String](Err(String("missing"))),
        Result[Int, String](Err(String("denied"))),
    ]
    var selective = piped(failures^).recover_if[ResultT[ListFamily, String]](is_missing, fallback).get()
    print("selected:", selective[0]._ok().value, "; kept:", selective[1]._err().value)
    var retried = piped(fail[Errors, Int](String("missing"))).or_else_if[Errors](is_missing, retry).get()
    print("selected retry:", retried._ok().value)

    var inspected = piped(fail[Errors, Int](String("original"))).tap_err[Errors](recovery_observer).get()
    print("inspection kept:", inspected._err().value)
    var observed = piped(fail[Errors, Int](String("original"))).flat_tap_err[Errors](recovery_observer).get()
    print("Result observer:", observed._err().value)

    comptime Validation = ValidationFamily[ListMonoid[String]]
    var accumulated = piped(fail[Validation, Int](List[String](["original"]))).flat_tap_err[Validation](recovery_validation_observer).get()
    print("Validation observer:", accumulated._err().value)
