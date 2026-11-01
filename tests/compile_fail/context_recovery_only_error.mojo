# error: no matching method in call to 'handle_error_with'
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from algebra_support.recovery_only import RecoveryOnly

def changed(var error: String) -> Result[Int, Int]:
    return Ok(42)

def main() raises:
    _ = pipeline[RecoveryOnly](Result[Int, String](Err(String("stored")))).handle_error_with(changed).get()
