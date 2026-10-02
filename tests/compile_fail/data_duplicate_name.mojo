# error: Data: two constructors are named Leaf
from fp.adt import Value, Cases, Data, Node

@fieldwise_init
struct Leaf[T: Copyable & Deinitable](Copyable):
    var value: Self.T

struct Ex(Data):
    comptime Layer[R: Value] = Cases[Leaf[Int], Leaf[String]]

def main():
    var n: Node[Ex] = Leaf[Int](1)
    _ = n
