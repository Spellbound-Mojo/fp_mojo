# error: no matching function in call to 'run'
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import piped
from fp.data import Result, Ok
from fp.callables import OnceUnary
comptime I = StateT[ResultT[ListFamily, String], Int]
@fieldwise_init
struct AELOnce(OnceUnary, Defaultable):
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var error: String) -> Int: return 1
def main():
    var pending = piped(fail[I, Int](String("bad"))).recover[I](AELOnce()).get()
    _ = run[I](pending^, 0)
