# error: no matching method
from fp.data import ok
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily

def success(var value: Int) raises Int -> Int: return value
def failure(var error: String) raises String -> Int: return 0
def main():
    var on_ok = kleisli[IdentityFamily](success)
    var on_err = kleisli[IdentityFamily](failure)
    _ = pipeline(ok[String](1)).fold_owned(on_ok, on_err)
