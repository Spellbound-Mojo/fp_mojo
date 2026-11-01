# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def show(value: Int) -> String: return String(value)
def size(var reason: String) -> Int: return reason.byte_length()
def main():
    var success = kleisli[IdentityFamily](show)
    var failure = kleisli[IdentityFamily](size)
    _ = Result[Int, String](Err(String("bad"))).redeem(success, failure)
