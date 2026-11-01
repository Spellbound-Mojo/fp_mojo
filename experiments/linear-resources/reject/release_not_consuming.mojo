"""Expected (native): 'c' abandoned without being explicitly destroyed"""
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


def leaky_close(var c: Conn) raises:
    pass


def read(c: Conn) -> Int:
    return c.id


def main():
    _ = linear_resource[Error](open_1, leaky_close).use(read)
