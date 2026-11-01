# error: lacking evidence to prove correctness
from context_reader_run_support import Produce, Once, Length
from fp.effects import Reader, run
from fp.algebra import ListFamily, traverse, map

def main():
    var first = 1
    var second = 2
    comptime I = Reader[Int]
    var pending = I.collect(Produce(Pointer(to=first)), List[Int]([1]))
    var mapped = map[I](pending^, Length())
    try:
        _ = run[I](mapped^, second)
    except error:
        pass
