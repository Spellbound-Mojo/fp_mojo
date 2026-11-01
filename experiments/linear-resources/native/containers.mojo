"""Can standard containers hold, move and explicitly destroy a linear value?"""
from std.utils import Variant


struct Handle(Movable, not Deinitable else "call 'close()'"):
    var id: Int

    def __init__(out self, id: Int):
        self.id = id

    def close(deinit self):
        print("close", self.id)


def close_handle(var h: Handle):
    h^.close()


def drop_int(var i: Int):
    _ = i


def main():
    # Optional: construct, take, destroy empty.
    var opt = Optional(Handle(1))
    var taken = opt.take()
    taken^.close()
    opt^.deinit_assert_empty()

    # Optional destroyed through its deinitializer hook.
    var opt2 = Optional(Handle(2))
    opt2^.deinit_with(close_handle)

    # Variant holding a linear alternative.
    var v = Variant[Handle, Int](Handle(3))
    if v.isa[Handle]():
        var h = v^.unwrap[Handle]()
        h^.close()
    else:
        v^.deinit_with[Int](drop_int)
