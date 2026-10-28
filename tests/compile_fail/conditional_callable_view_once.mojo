# error: no matching method
from fp.functions import pipeline, kleisli
from fp.algebra import IdentityFamily, ListFamily
from fp.callables import OnceUnary
from fp.data import Result, Err
from fp.effects import ResultT

@fieldwise_init
struct Restore(OnceUnary):
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var reason: String) -> Int: return 1

def choose(reason: String) -> Bool: return True

def main():
    var handler = kleisli[IdentityFamily](Restore())
    var failures: List[Result[Int, String]] = [Err(String("bad"))]
    _ = pipeline[ResultT[ListFamily, String]](failures^).recover_if(choose, handler^).get()
