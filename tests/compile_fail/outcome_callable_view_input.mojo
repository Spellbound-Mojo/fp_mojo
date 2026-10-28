# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def size(var reason: String) -> Int: return reason.byte_length()
def main():
    var handler = kleisli[IdentityFamily](size)
    _ = pipeline(Result[Int, Int](Err(1))).map_err(handler).get()
