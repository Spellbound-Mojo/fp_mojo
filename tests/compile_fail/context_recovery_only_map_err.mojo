# error: no matching method in call to 'map_err'
from fp.functions import pipeline
from fp.data import Result, Err
from algebra_support.recovery_only import RecoveryOnly

def changed(var error: String) -> Int:
    return 42

def main() raises:
    _ = pipeline[RecoveryOnly](Result[Int, String](Err(String("stored")))).map_err(changed).get()
