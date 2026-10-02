"""Distinguish requested deep copies from abstraction copies and native drops."""
from fp.functions import as_unary, pipe
from fp.iteration import fold_left
from fp.adt import Data, Cases, Choice, Value
import fp
from std.builtin.variadics import TypeList
from std.iter import iter
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Large(Copyable):
    var values: List[Int]
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.values = copy.values.copy()
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1

def duplicate(value: Large) -> Large: return value.copy()
def read(value: Large) -> Int: return len(value.values)
def append(var value: Large, var item: Int) -> Large:
    value.values.append(item)
    return value^
def consume(var value: Large) -> Int: return len(value.values)
struct LargeData(Data):
    comptime Layer[R: Value] = Cases[Large]

def exercise(mode: Int, library: Bool, copies: ArcPointer[Int], drops: ArcPointer[Int]) -> Int:
    var values = List[Int](capacity=256)
    for i in range(256): values.append(i)
    var value = Large(values^, copies, drops)
    if mode == 0:
        if library:
            var copy_stage = as_unary(duplicate)
            var read_stage = as_unary(read)
            comptime Path = TypeList.of[Trait=Movable & Deinitable, Large, Int]()
            return pipe[Path](value^, copy_stage, read_stage)
        return read(duplicate(value))
    if mode == 1:
        if library: return read(fold_left(append, value^, iter(range(4))))
        for i in range(4): value = append(value^, i)
        return read(value)
    var subject: Choice[LargeData] = value^
    if library:
        # A match borrows the stored constructor: no copy, and one drop with the subject.
        return fp.match(subject, read)
    return consume(subject^.unwrap[Large]())

def main() raises:
    for mode in range(3):
        for library in range(2):
            var copies = ArcPointer(0)
            var drops = ArcPointer(0)
            assert_equal(exercise(mode, Bool(library), copies, drops), 260 if mode == 1 else 256)
            assert_equal(copies[], 1 if mode == 0 else 0)
            assert_equal(drops[], 2 if mode == 0 else 1)
