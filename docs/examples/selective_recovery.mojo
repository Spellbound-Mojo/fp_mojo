"""Observe failures, retry selected errors and recover a missing value."""
from fp.data import Result, Ok, Err
from fp.functions import piped


def record_error(error: String) -> Result[NoneType, String]:
    print("observed:", error)
    return Ok(NoneType())


def can_retry(error: String) -> Bool: return error == "retry"
def missing(error: String) -> Bool: return error == "missing"
def retry(var error: String) -> Result[Int, String]: return Ok(42)
def default_value(var error: String) -> Int: return 0
def success(value: Int) -> String: return "value: " + String(value)
def failure(var error: String) -> String: return "error: " + error


def main():
    var messages: List[String] = ["retry", "missing", "fatal"]
    for message in messages^:
        var result = (
            piped(Result[Int, String](Err(message)))
            .flat_tap_err(record_error)
            .or_else_if(can_retry, retry)
            .recover_if(missing, default_value)
            .get()
        )
        print(result^.fold_owned(success, failure))
