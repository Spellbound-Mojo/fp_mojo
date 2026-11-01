"""Counted alignment sources and assertions shared by runtime and ownership checks."""
from fp.data import Ior, Left, Right, Both
from std.iter import Iterator, IterableOwned, next
from std.memory import ArcPointer
from std.testing import assert_equal


def i4_total(var value: Ior[Int,Int]) -> Int:
    if value.isa[Left[Int]](): return value[Left[Int]].value
    if value.isa[Right[Int]](): return value[Right[Int]].value
    return value[Both[Int,Int]].left + value[Both[Int,Int]].right


def i4_done[I: Iterator](mut value: I) raises where conforms_to(I.Element, Deinitable):
    for _ in range(2):
        var stopped = False
        try: _ = next(value)
        except StopIteration: stopped = True
        assert_equal(stopped, True)


@fieldwise_init
struct I4Source(Iterator, IterableOwned):
    comptime Element = Int
    comptime IteratorOwnedType = Self
    var position: Int
    var end: Int
    var id: Int
    var pulls: ArcPointer[List[Int]]
    var drops: ArcPointer[Int]
    def __iter__(var self) -> Self:
        self.position = 0
        return self^
    def __next__(mut self) raises StopIteration -> Int:
        var value = self.position
        self.position += 1
        self.pulls[].append(self.id * 100 + value)
        if value == self.end: raise StopIteration()
        return value
    def bounds(self) -> Tuple[Int,Optional[Int]]:
        return (max(0,self.end-self.position),Optional(max(0,self.end-self.position)))
    def __deinit__(deinit self): self.drops[] += 1
