# error: repeatable
from fp.algebra import ResultFamily, ListFamily, fail
from fp.functions import piped
from fp.data import Result, Ok, Err
from fp.effects import ResultT
from fp.callables import OnceUnary
@fieldwise_init
struct AEOnce(OnceUnary, Defaultable):
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var error: String) -> Int: return 1
def main():
    comptime F = ResultT[ListFamily, String]
    _ = piped(fail[F, Int](String("bad"))).recover[F](AEOnce()).get()
