# error: is not a constructor of
from fp.adt import Value, Cases, Data, Node

@fieldwise_init
struct Leaf(Copyable):
    var value: Int

@fieldwise_init
struct Stranger(Copyable):
    var value: Int

struct Ex(Data):
    comptime Layer[R: Value] = Cases[Leaf]

def main():
    var n: Node[Ex] = Stranger(1)
    _ = n
