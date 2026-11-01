"""Observation preserves lazy failure construction and exact native errors."""
from test_applicative_error_extension import AEXFamily, AEXConstructionError
from test_applicative_error_lifting_construction import AELConstructorBase, AELConstructionFailure
from fp.algebra import ValidationFamily, Semigroup
from fp.effects import ReaderT, action, run
from fp.callables import BorrowOnceCallable
from fp.data import Result, Ok, Err
from fp.functions import pipeline
from std.testing import assert_equal


def eoc_plain(error: String) -> Int: return 0
def eoc_success(error: String) -> Result[Int, String]: return Ok(0)
def eoc_failure(error: String) -> Result[Int, String]: return Err(String("observer"))


@fieldwise_init
struct EOCRead(BorrowOnceCallable):
    comptime Payload = Int
    comptime Result = Result[Int, String]
    def invoke_once(deinit self, ref env: Int) raises Never capturing -> Self.Result:
        return Err(String("construct"))


struct EOCSemigroup(Semigroup):
    comptime Value = String
    comptime Error = Int
    @staticmethod
    def combine(var left: String, var right: String) raises Int -> String: raise 88


def main() raises:
    var code = 0
    try:
        _ = pipeline[AEXFamily](Result[Int, String](Err(String("construct")))).tap_err(eoc_plain).get()
    except error:
        comptime assert type_of(error) == AEXConstructionError
        code = error.value
    assert_equal(code, 31)
    code = 0
    try:
        _ = pipeline[AEXFamily](Result[Int, String](Err(String("construct")))).flat_tap_err(eoc_success).get()
    except error:
        comptime assert type_of(error) == AEXConstructionError
        code = error.value
    assert_equal(code, 31)
    var retained: String
    try:
        var result = pipeline[AEXFamily](Result[Int, String](Err(String("construct")))).flat_tap_err(eoc_failure).get()
        retained = result._err().value.copy()
    except error: retained = "unexpected native error"
    assert_equal(retained, "observer")
    comptime D = ReaderT[AELConstructorBase, Int]
    def deferred_observer(error: String) -> D.Pure[Int]: return D.pure(0)
    var pending = pipeline[D](action[D, Int](EOCRead())).flat_tap_err(deferred_observer).get()
    code = 0
    try:
        _ = run[D](pending^, 0)
    except error:
        comptime assert type_of(error) == AELConstructionFailure
        code = error.value
    assert_equal(code, 31)
    comptime V = ValidationFamily[EOCSemigroup]
    code = 0
    try:
        _ = pipeline[V](Result[Int, String](Err(String("original")))).flat_tap_err(eoc_failure).get()
    except error:
        comptime assert type_of(error) == Int
        code = error
    assert_equal(code, 88)
    print("error observation construction: ok")
