# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def success(value: Int) raises Int -> Int: return value
def failure(var reason: String) raises String -> Int: return 0
def main():
    var on_ok = kleisli[IdentityFamily](success)
    var on_err = kleisli[IdentityFamily](failure)
    _ = pipeline(Result[Int, String](Err(String("bad")))).redeem(on_ok, on_err).get()
