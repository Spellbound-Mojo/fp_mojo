# error: Data: field pair of Bad uses R
from fp.adt import Value, Cases, Data, Node

@fieldwise_init
struct Leaf(Copyable):
    var value: Int

@fieldwise_init
struct Bad[R: Value](Movable):
    var pair: Tuple[Self.R, Int]

struct Ex(Data):
    comptime Layer[R: Value] = Cases[Leaf, Bad[R]]

def main():
    var n: Node[Ex] = Leaf(1)
    _ = n
