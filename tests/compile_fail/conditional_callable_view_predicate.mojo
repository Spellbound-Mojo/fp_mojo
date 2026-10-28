# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def choose(reason: String) -> Int: return 1
def restore(var reason: String) -> Int: return 1

def main():
    var handler = kleisli[IdentityFamily](restore)
    _ = pipeline(Result[Int, String](Err(String("bad")))).recover_if(choose, handler).get()
