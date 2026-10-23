# error: constraint
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import piped
from fp.data import Result, Ok
from fp.callables import BorrowOnceCallable
comptime R = ReaderT[ResultFamily[String], Int]
@fieldwise_init
struct AELNative(BorrowOnceCallable, Defaultable):
    comptime Payload = Int
    comptime Result = Result[Int, String]
    comptime Failure = Int
    def invoke_once(deinit self, ref environment: Int) raises Int capturing -> Self.Result:
        raise 1
def restore(var error: String) raises String -> Int: raise String("native")
def main() raises:
    var pending = piped(action[R, Int](AELNative())).recover[R](restore).get()
    _ = run[R](pending^, 0)
