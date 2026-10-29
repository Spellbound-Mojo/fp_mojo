from fp.algebra import IdentityFamily, ListFamily, ListMonoid, ResultFamily, ValidationFamily, fail
from fp.data import Result, Ok, Err
from fp.effects import ResultT
from fp.functions import pipeline, kleisli, identity


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


def describe_value(var value: Int) -> String:
    return String(value)


def describe_outcome(var outcome: Result[Int, String]) -> String:
    return outcome^.fold_owned(describe_value, identity[String])


def main() raises:
    comptime Errors = ResultFamily[String]
    var restore = kleisli[IdentityFamily](fallback)
    var retrying = kleisli[Errors](retry)
    var recovered = pipeline(fail[Errors, Int](String("missing"))).or_else(retrying).get()
    print("retried:", recovered^.raise_on_err())

    var entries: List[Result[Int, String]] = [
        Result[Int, String](Ok(3)),
        Result[Int, String](Err(String("missing"))),
        Result[Int, String](Ok(5)),
    ]
    var recovered_entries: List[Result[Int, String]] = pipeline[ResultT[ListFamily, String]](entries^).recover(restore).get()
    var values = pipeline(recovered_entries^).sequence().raise_on_err()
    print("entries:", values[0], values[1], values[2])

    comptime Nested = ResultT[Errors, String]
    var outer = Result[Result[Int, String], String](Err(String("connection failed")))
    var untouched = pipeline[Nested](outer^).recover(restore).get()
    print("outer:", untouched^.swap().to_optional().value())

    var failures: List[Result[Int, String]] = [
        Result[Int, String](Err(String("missing"))),
        Result[Int, String](Err(String("denied"))),
    ]
    var selective = pipeline[ResultT[ListFamily, String]](failures^).recover_if(is_missing, restore).get()
    var descriptions = pipeline(selective^).map(describe_outcome).get()
    print("selected:", descriptions[0], "; kept:", descriptions[1])
    var retried = pipeline(fail[Errors, Int](String("missing"))).or_else_if(is_missing, retrying).get()
    print("selected retry:", retried^.raise_on_err())

    var inspected = pipeline(fail[Errors, Int](String("original"))).tap_err(recovery_observer).get()
    print("inspection kept:", inspected^.swap().to_optional().value())
    var observed = pipeline(fail[Errors, Int](String("original"))).flat_tap_err(recovery_observer).get()
    print("Result observer:", observed^.swap().to_optional().value())

    comptime Validation = ValidationFamily[ListMonoid[String]]
    var accumulated = pipeline[Validation](fail[Validation, Int](List[String](["original"]))).flat_tap_err(recovery_validation_observer).get()
    print("Validation observer:", accumulated^.swap().to_optional().value())
