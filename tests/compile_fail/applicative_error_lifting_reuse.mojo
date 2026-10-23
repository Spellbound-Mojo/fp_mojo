# error: uninitialized
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import piped
from fp.data import Result, Ok
from fp.callables import OnceUnary
comptime R = ReaderT[ResultFamily[String], Int]
@fieldwise_init
struct AELCaptured(OnceUnary):
    var text: String
    comptime Arg = String
    comptime Out = Int
    def call_once(deinit self, var error: String) -> Int: return self.text.byte_length()
def main():
    var handler = AELCaptured(String("owner"))
    var pending = piped(fail[R, Int](String("bad"))).recover[R](handler^).get()
    _ = handler^.call_once(String())
    _ = run[R](pending^, 0)
