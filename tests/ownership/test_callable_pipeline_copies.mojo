"""Count native value copies through promotion, owned stages and final borrowing."""
from fp.functions import as_unary, pipe
from std.builtin.variadics import TypeList
from std.memory import ArcPointer
from std.testing import assert_equal

@fieldwise_init
struct Counted(Copyable):
    var value: Int
    var copies: ArcPointer[Int]
    var drops: ArcPointer[Int]
    def __init__(out self, *, copy: Self):
        self.value = copy.value
        self.copies = copy.copies
        self.drops = copy.drops
        self.copies[] += 1
    def __deinit__(deinit self): self.drops[] += 1

def number(value: Counted) -> Int: return value.value

def exercise(library: Bool, copies: ArcPointer[Int], drops: ArcPointer[Int]) -> Int:
    var state = Counted(0, copies, drops)
    def increment(var value: Counted) {var state^} -> Counted:
        state.value += 1
        value.value += state.value
        return value^
    var add = as_unary(increment^)
    var finish = as_unary(number)
    comptime Path = TypeList.of[Trait=Movable & Deinitable, Counted, Int]()
    if library: return pipe[Path](Counted(7, copies, drops), add, finish)
    return finish(add(Counted(7, copies, drops)))

def main() raises:
    for library in range(2):
        var copies = ArcPointer(0)
        var drops = ArcPointer(0)
        assert_equal(exercise(Bool(library), copies, drops), 8)
        assert_equal(copies[], 0)
        assert_equal(drops[], 2)
