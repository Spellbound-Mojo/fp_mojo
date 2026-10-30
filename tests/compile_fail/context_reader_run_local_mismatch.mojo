# error: lacking evidence to prove correctness
from context_reader_run_support import Produce, Once, Length
from fp.effects import Reader, run
from fp.algebra import ListFamily, traverse, map

from fp.callables import BorrowCallable
from fp.effects import local

@fieldwise_init
struct Replace(BorrowCallable):
    comptime Payload = Int
    comptime Result = Int
    def invoke(self, ref value: Int) -> Int:
        return value + 1

def main():
    var first = 1
    comptime I = Reader[Int]
    var pending = I.collect(Produce(Pointer(to=first)), List[Int]([1]))
    var scoped = local[I](pending^, Replace())
    try:
        _ = run[I](scoped^, first)
    except error:
        pass
