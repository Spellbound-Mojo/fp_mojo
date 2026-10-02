"""Name a native callable adapter before moving it into another native value."""
from std.testing import assert_equal
from std.memory import ArcPointer

@fieldwise_init
struct Inner[Produced: Movable & Deinitable, F: def() -> Produced](Movable):
    var function: Self.F

@fieldwise_init
struct Outer[T: Movable & Deinitable](Movable):
    var value: Self.T

def make[Produced: Movable & Deinitable, F: def() -> Produced](var function: F) -> Outer[Inner[Produced, F]] where F.Produced == Produced:
    var inner = Inner[Produced, F](function^)
    return Outer[Inner[Produced, F]](inner^)

@fieldwise_init
struct Resource(Movable):
    var destroyed: ArcPointer[Int]
    def __deinit__(deinit self):
        self.destroyed[] += 1

def run(destroyed: ArcPointer[Int]) -> Int:
    var resource = Resource(destroyed)
    def native() {var resource^} -> Int:
        return resource.destroyed[] + 42
    var wrapped = make(native^)
    return wrapped.value.function()

def main() raises:
    var destroyed = ArcPointer(0)
    assert_equal(run(destroyed), 42)
    assert_equal(destroyed[], 1)
