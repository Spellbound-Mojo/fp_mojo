# error: is not a constructor of data_wrong_access.Ex
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
    var n: Node[Ex] = Leaf(1)
    print(n[Stranger].value)
