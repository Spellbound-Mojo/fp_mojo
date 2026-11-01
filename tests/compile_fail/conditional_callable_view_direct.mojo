# error: no matching method
from fp.functions import kleisli
from fp.algebra import IdentityFamily
from fp.data import Result, Err

def choose(reason: String) -> Bool: return True
def restore(var reason: String) -> String: return reason^

def main():
    var handler = kleisli[IdentityFamily](restore)
    _ = Result[Int, String](Err(String("bad"))).recover_if(choose, handler)
