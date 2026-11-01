# error: Result conditional: incompatible native errors
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def choose(reason: String) raises Int -> Bool: return True
def restore(var reason: String) raises String -> Int: return 1

def wrong() raises Int:
    var handler = kleisli[IdentityFamily](restore)
    _ = Result[Int, String](Err(String("bad"))).recover_if(choose, handler)

def main():
    try: wrong()
    except _: pass
