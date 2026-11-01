# error: cannot call function that may raise
from fp.functions import kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def fail(var reason: String) raises Int -> Int: raise 1

def main() raises String:
    var handler = kleisli[IdentityFamily](fail)
    _ = Result[Int, String](Err(String("bad"))).value_or(handler)
