"""A raising call while a linear value is live, with no handling on the error path."""


struct Handle(Movable, not Deinitable else "call 'close()'"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def close(deinit self):
        pass


def may_raise() raises:
    raise Error("x")


def unguarded() raises:
    var h = Handle(1)
    may_raise()
    h^.close()


def main() raises:
    unguarded()
