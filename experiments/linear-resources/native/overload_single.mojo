"""Control for overload_crash.mojo: the linear overload alone."""
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


def make[T: Movable, X: Movable & Deinitable, //, E: Movable & Deinitable, A: def() raises X -> T](var acquire: A) raises X -> Int where not conforms_to(T, Deinitable):
    var c = acquire()
    rebind_var[Conn](c^).drop()
    return 1


def main() raises:
    print(make[Error](open_1))
