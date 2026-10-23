"""Third-party failure construction keeps its exact native error and timing."""
from test_applicative_error_lifting_construction import AELConstructorBase, AELConstructionFailure
from test_applicative_error_extension import AEXFamily
from fp.effects import ReaderT, run
from fp.functions import piped
from fp.data import Result, Ok, Err
from std.testing import assert_equal

def soc_accept(value: Int) -> Bool: return True
def soc_reject(value: Int) -> Bool: return False
def soc_error(value: Int) -> String: return "construct"
def soc_observe(outcome: Result[Int, String]) -> Result[Int, String]: return Ok(0)
def soc_failed(outcome: Result[Int, String]) -> Result[Int, String]: return Err(String("observer"))
def soc_ok(var value: Int) -> Int: return value
def soc_err(var error: String) -> Int: return 42

def main() raises:
    comptime F = AELConstructorBase
    var code: Int
    try:
        var accepted = piped(Result[Int, String](Ok(1))).ensure[F](soc_accept, soc_error).get()
        code = accepted._ok().value
    except error: code = -1
    assert_equal(code, 1)
    try:
        _ = piped(Result[Int, String](Ok(1))).ensure[F](soc_reject, soc_error).get()
    except error:
        comptime assert type_of(error) == AELConstructionFailure
        code = error.value
    assert_equal(code, 31)
    var retained: String
    try:
        var existing = piped(Result[Int, String](Err(String("construct")))).ensure[F](soc_reject, soc_error).get()
        retained = existing._err().value.copy()
    except error: retained = "unexpected"
    assert_equal(retained, "construct")
    code = 0
    try:
        _ = piped(Result[Int, String](Err(String("construct")))).attempt_tap[F](soc_observe).get()
    except error:
        comptime assert type_of(error) == AELConstructionFailure
        code = error.value
    assert_equal(code, 31)
    try:
        var replaced = piped(Result[Int, String](Err(String("construct")))).attempt_tap[F](soc_failed).get()
        retained = replaced._err().value.copy()
    except error: retained = "unexpected"
    assert_equal(retained, "observer")
    assert_equal(piped(Result[Int, String](Err(String("construct")))).redeem[AEXFamily](soc_ok, soc_err).get()._ok().value, 42)
    comptime D = ReaderT[F, Int]
    var pending = piped(D.pure(1)).ensure[D](soc_reject, soc_error).get()
    code = 0
    try: _ = run[D](pending^, 0)
    except error:
        comptime assert type_of(error) == AELConstructionFailure
        code = error.value
    assert_equal(code, 31)
    print("shared outcomes construction: ok")
