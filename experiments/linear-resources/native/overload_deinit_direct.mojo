"""The Deinitable-bounded overload spelled without an alias, called with a linear result."""
from std.builtin.rebind import rebind_var


struct Conn(Movable, not Deinitable else "call 'drop()'"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def drop(deinit self):
        pass


def open_1() raises -> Conn:
    return Conn(1)


comptime _RaisingThunk[R: Movable & Deinitable, E: Movable & Deinitable] = def() raises E -> R


def make[T: Movable & Deinitable, X: Movable & Deinitable, //, E: Movable & Deinitable, A: def() raises X -> T](var acquire: A) raises X -> Int:
    return 0


def main() raises:
    print(make[Error](open_1))
