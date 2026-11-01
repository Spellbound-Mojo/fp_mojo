"""Unpatched library: passing a linear acquisition to `resource`."""
from fp.effects import resource


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


def query(c: Conn) raises -> Int:
    return c.id


def main():
    _ = resource[Error](open_1, close).use(query)
