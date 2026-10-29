from fp.algebra import ErrorRecovery, ApplicativeError, ResultFamily
from fp.functions import pipeline
from fp.callables import UnaryContract, BinaryContract, ThunkContract
from fp.data import Result, Err, Ok
from std.testing import assert_equal

from algebra_support.recovery_only import RecoveryOnly


def restore(var error: String) -> Result[Int, String]:
    return Ok(42)

def main() raises:
    comptime assert not conforms_to(RecoveryOnly, ApplicativeError)
    var code = 0
    try:
        _ = pipeline[RecoveryOnly](Result[Int, String](Err(String("stored")))).handle_error_with(restore).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 709)
    code = 0
    try:
        _ = pipeline[RecoveryOnly](Result[Int, String](Err(String("stored")))).or_else(restore).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 709)
    code = 0
    try:
        _ = pipeline[RecoveryOnly](Result[Int, String](Ok(42))).attempt().get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 709)
    print("Pipeline recovery: selected family owns native construction errors without ApplicativeError")

