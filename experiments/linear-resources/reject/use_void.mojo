"""Expected: fp: use_void is not available for a linear value"""
from fp.effects import linear_resource


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


def both(pair: Tuple[Conn, Conn]) -> Int:
    return 0


def main():
    _ = linear_resource[Error](open_1, close).use_void()
