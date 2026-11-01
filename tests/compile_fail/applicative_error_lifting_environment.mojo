# error: uninitialized
from fp.algebra import ResultFamily, ListFamily, StringMonoid, ListMonoid, fail, pure
from fp.effects import ReaderT, StateT, WriterT, OptionalT, ResultT, action, run
from fp.functions import pipeline
from fp.data import Result, Ok
from fp.callables import BorrowOnceCallable
comptime Inner = ReaderT[ResultFamily[String], Int]
comptime Outer = ReaderT[Inner, String]
@fieldwise_init
struct AELRead(BorrowOnceCallable, Defaultable):
    comptime Payload = String
    comptime Result = Inner.Pure[Int]
    def invoke_once(deinit self, ref environment: String) raises Never capturing -> Self.Result:
        return pure[Inner](environment.byte_length())
def restore(var error: String) -> type_of(action[Outer, Int](AELRead())):
    return action[Outer, Int](AELRead())
def main():
    var outer = String("configuration")
    var pending = pipeline[Outer](fail[Outer, Int](String("bad"))).or_else(restore).get()
    var inner = run[Outer](pending^, outer)
    var moved = outer^
    print(moved)
    _ = run[Inner](inner^, 0)
