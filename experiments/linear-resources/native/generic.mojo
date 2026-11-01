"""Generic code over values that may be linear: storage, borrowing and consumption."""


struct Handle(Movable, not Deinitable else "call 'close()'"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def close(deinit self):
        print("close", self.id)


struct Lease[T: Movable](Movable, Deinitable where conforms_to(T, Deinitable)):
    """Linear exactly when its payload is."""
    var value: Self.T

    def __init__(out self, var value: Self.T):
        self.value = value^

    def into_value(deinit self) -> Self.T:
        return self.value^


def bracket[T: Movable, U: Movable & Deinitable, //,
            A: def() raises -> T, B: def(T) raises -> U, R: def(var T) raises](
    acquire: A, use: B, release: R
) raises -> U:
    """Acquire, borrow for use, and release on both paths. Release errors after a
    use error are dropped here; the library would accumulate them."""
    var lease = Lease(acquire())
    var result: U
    try:
        result = use(lease.value)
    except e:
        try:
            release(lease^.into_value())
        except:
            pass
        raise e^
    release(lease^.into_value())
    return result^


def acquire_handle() raises -> Handle:
    return Handle(7)


def read_handle(h: Handle) raises -> Int:
    if h.id < 0:
        raise Error("bad handle")
    return h.id * 10


def fail_on_use(h: Handle) raises -> Int:
    raise Error("use failed")


def release_handle(var h: Handle) raises:
    h^.close()


def acquire_int() raises -> Int:
    return 3


def read_int(i: Int) raises -> Int:
    return i + 1


def release_int(var i: Int) raises:
    print("release int", i)


def main() raises:
    print(bracket(acquire_handle, read_handle, release_handle))
    try:
        _ = bracket(acquire_handle, fail_on_use, release_handle)
    except e:
        print("caught:", e)
    print(bracket(acquire_int, read_int, release_int))
    # An ordinary payload keeps an implicitly destructible lease.
    var plain = Lease(5)
    _ = plain^
