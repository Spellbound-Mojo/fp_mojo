# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def choose(reason: Int) -> Bool: return True
def restore(var reason: String) -> Int: return 1

def main():
    var handler = kleisli[IdentityFamily](restore)
    _ = pipeline(Result[Int, Int](Err(1))).recover_if(choose, handler).get()
