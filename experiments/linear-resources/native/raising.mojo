"""Raising while a linear value is live: what must the code do?"""


struct Handle(Movable, not Deinitable else "call 'close()'"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def close(deinit self):
        print("close", self.id)

    def close_raising(deinit self) raises:
        print("close_raising", self.id)
        if self.id < 0:
            raise Error("close failed")


def may_raise(fail: Bool) raises:
    if fail:
        raise Error("work failed")


def guarded(fail: Bool) raises:
    var h = Handle(1)
    try:
        may_raise(fail)
    except e:
        h^.close()
        raise e^
    h^.close()


def raising_close() raises:
    var h = Handle(-1)
    h^.close_raising()


def main():
    try:
        guarded(False)
        guarded(True)
    except e:
        print("caught:", e)
    try:
        raising_close()
    except e:
        print("caught:", e)
