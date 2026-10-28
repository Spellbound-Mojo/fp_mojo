# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def choose(reason: String) raises Int -> Bool: return True
def restore(var reason: String) raises String -> Int: return 1

def main():
    var handler = kleisli[IdentityFamily](restore)
    _ = pipeline(Result[Int, String](Err(String("bad")))).raising[Int]().recover_if(choose, handler).get()
