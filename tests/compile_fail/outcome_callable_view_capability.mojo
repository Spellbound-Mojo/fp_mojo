# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err
from error_mapping_support import Probe

def success(value: Int) -> Int: return value
def failure(var reason: String) -> Int: return 0
def main():
    var on_ok = kleisli[IdentityFamily](success)
    var on_err = kleisli[IdentityFamily](failure)
    _ = pipeline[Probe[String]](Result[Int, String](Err(String("bad")))).redeem(on_ok, on_err).get()
