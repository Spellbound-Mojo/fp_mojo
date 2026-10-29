"""Handle an original outcome while preserving its selected family."""
from fp.data import Result, Ok, Err
from fp.effects import Reader, ResultT, run
from fp.algebra import IdentityFamily
from fp.functions import pipeline, kleisli


def double(var value: Int) -> Int:
    return value * 2


def text(var value: Int) -> Result[String, Int]:
    return Ok(String(value))


def code(var error: String) -> Result[String, Int]:
    return Err(error.byte_length())


def main() raises:
    comptime Environment = Reader[Int]
    comptime Deferred = ResultT[Environment, String]
    var recovered = 0
    def fallback(var error: String) {mut recovered} -> Int:
        recovered += 1
        return 7

    var scale = kleisli[IdentityFamily](double)
    var pending = pipeline[Deferred](Deferred.fail[Int](String("missing"))).redeem(scale, fallback).map(scale).get()
    print("before run:", recovered)
    print("recovered:", run[Environment](pending^, 0).raise_on_err(), "; handled:", recovered)

    var error_calls = 0
    def reject(var value: Int) -> Deferred.Pure[Int]:
        return Deferred.fail[Int](String("handler failure"))
    def retry(var error: String) {mut error_calls} -> Deferred.Pure[Int]:
        error_calls += 1
        return Deferred.pure(9)
    var original = pipeline[Deferred](Deferred.pure(3)).redeem_with(reject, retry).get()
    print("preserved:", run[Environment](original^, 0).swap().to_optional().value(), "; opposite calls:", error_calls)

    var changed = pipeline(Result[Int, String](Err(String("missing")))).redeem_with(text, code).get()
    print("changed error:", changed^.swap().to_optional().value())
