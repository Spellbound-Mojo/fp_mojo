# error: no matching method in call to 'recover'
from fp.functions import pipeline
from fp.data import Result, Err
from algebra_support.recovery_only import RecoveryOnly

def restore(var error: String) -> Int:
    return 42

def main() raises:
    _ = pipeline[RecoveryOnly](Result[Int, String](Err(String("stored")))).recover(restore).get()
