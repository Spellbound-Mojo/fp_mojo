"""Dropping a linear value, directly and inside an Optional."""


struct Handle(Movable, not Deinitable else "call 'close()'"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def close(deinit self):
        pass


def main():
    var h = Handle(1)
    var o = Optional(Handle(2))
