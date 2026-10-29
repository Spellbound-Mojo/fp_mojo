# error: no matching method in call to 'attempt_tap'
from fp.functions import pipeline
from fp.data import Result, Ok, Err
from algebra_support.recovery_only import RecoveryOnly

def observe(outcome: Result[Int, String]) -> Result[NoneType, String]:
    return Ok(NoneType())

def main() raises:
    _ = pipeline[RecoveryOnly](Result[Int, String](Err(String("stored")))).attempt_tap(observe).get()
