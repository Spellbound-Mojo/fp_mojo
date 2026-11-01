"""Which spellings of a function-typed parameter infer a linear result without crashing?"""


struct Conn(Movable, not Deinitable else "call 'close()'"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def close(deinit self) raises:
        pass


def open_1() raises -> Conn:
    return Conn(1)


def close(var c: Conn) raises:
    c^.close()


# Variant 1: the error is inferred separately from the explicit E.
def with_inferred_error[T: Movable, X: Movable & Deinitable, //, E: Movable & Deinitable,
                        A: def() raises X -> T](var acquire: A) raises X -> T where not conforms_to(T, Deinitable):
    return acquire()


# Variant 2: the callbacks raise exactly the explicit E.
def with_exact_error[T: Movable, //, E: Movable & Deinitable,
                     A: def() raises E -> T, R: def(var T) raises E](var acquire: A, var release: R) raises E:
    var value = acquire()
    release(value^)


def main() raises:
    with_exact_error[Error](open_1, close)
    print("exact error: ok")
    var c = with_inferred_error[Error](open_1)
    c^.close()
    print("inferred error: ok")
